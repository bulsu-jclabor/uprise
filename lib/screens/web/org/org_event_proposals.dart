import 'dart:async';
import 'dart:convert';
import '../../../utils/platform_file_utils.dart' as platform_file_utils;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:http/http.dart' as http;

// Import export utilities (same as student accounts)
import '../../../widgets/admin_export_button.dart';
import 'export_util.dart';
import 'export_pdf.dart';

// ============ COLOR SCHEME ============
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B); 
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
}

// ============ MAIN SCREEN ============
class OrgEventProposalsScreen extends StatefulWidget {
  final String orgId;
  const OrgEventProposalsScreen({super.key, required this.orgId});

  @override
  State<OrgEventProposalsScreen> createState() => _OrgEventProposalsScreenState();
}

class _OrgEventProposalsScreenState extends State<OrgEventProposalsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery   = '';
  String _filterStatus  = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  // Streams for stats cards
  Stream<QuerySnapshot> get _totalStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot> get _pendingStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'pending')
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot> get _approvedStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot> get _forReviewStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'for_review')
      .snapshots(includeMetadataChanges: true);
  
  // Main proposals stream
  Stream<QuerySnapshot> get _proposalsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('submittedAt', descending: true)
      .snapshots(includeMetadataChanges: true);

  void _openSubmitModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SubmitProposalModal(orgId: widget.orgId),
    ).then((_) => setState(() {}));
  }

  void _refreshAfterModal() => setState(() {});

  Future<void> _deleteProposal(String docId, String title) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await FirebaseFirestore.instance.collection('event_proposals').doc(docId).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_proposal',
        module: 'event_proposals',
        details: {'orgId': widget.orgId, 'proposalId': docId, 'title': title},
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting proposal: $e')),
        );
      }
    }
  }

  void _confirmDelete(String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Proposal'),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProposal(docId, title);
            },
            style: ElevatedButton.styleFrom(backgroundColor: OrgColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openEditModal(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SubmitProposalModal(
        orgId: widget.orgId,
        editDocId: docId,
        existing: data,
      ),
    ).then((_) => _refreshAfterModal());
  }

  void _openViewModal(Map<String, dynamic> data) {
    showDialog(context: context, builder: (_) => _ViewProposalModal(data: data));
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var filtered = docs;
    if (_filterStatus != 'All') {
      final statusKey = _filterStatus.toLowerCase().replaceAll(' ', '_');
      filtered = filtered
          .where((d) =>
              ((d.data() as Map)['status']?.toString().toLowerCase() ?? '') ==
              statusKey)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        final data = d.data() as Map;
        return (data['title'] ?? '').toString().toLowerCase().contains(q) ||
            (data['category'] ?? '').toString().toLowerCase().contains(q) ||
            (data['location'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }
    return filtered;
  }

  // ========== EXPORT FUNCTIONALITY (CSV / PDF) ==========
  Future<void> _exportProposals(String format) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('event_proposals')
        .where('orgId', isEqualTo: widget.orgId)
        .orderBy('submittedAt', descending: true)
        .get();
    
    final docs = _applyFilters(snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>().toList());
    
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final now = DateTime.now().toString().substring(0, 10);
    final fileName = 'event_proposals_$now';

    if (format == 'csv') {
      final csvContent = StringBuffer();
      csvContent.writeln('Proposal ID,Title,Category,Audience,Description,Date,Time,Location,Status,Submitted By,Submitted At');
      for (final doc in docs) {
        final d = doc.data();
        final proposalNum = 'EP-${doc.id.substring(0, 4).toUpperCase()}';
        final row = [
          proposalNum,
          _escapeCsv(d['title'] ?? ''),
          _escapeCsv(d['category'] ?? ''),
          _escapeCsv(d['audience'] ?? ''),
          _escapeCsv(d['description'] ?? ''),
          d['date'] != null ? DateFormat('yyyy-MM-dd').format((d['date'] as Timestamp).toDate()) : '',
          d['time'] ?? '',
          _escapeCsv(d['location'] ?? ''),
          d['status'] ?? 'pending',
          d['submittedByEmail'] ?? '',
          d['submittedAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((d['submittedAt'] as Timestamp).toDate()) : '',
        ];
        csvContent.writeln(row.join(','));
      }
      await OrgExportUtil.saveText(csvContent.toString(), '$fileName.csv', mimeType: 'text/csv');
    } 
    else if (format == 'pdf') {
      final List<List<String>> rows = docs.map((doc) {
        final d = doc.data();
        final proposalNum = 'EP-${doc.id.substring(0, 4).toUpperCase()}';
        return <String>[
          proposalNum,
          (d['title'] as String?) ?? '',
          (d['category'] as String?) ?? '',
          (d['audience'] as String?) ?? '',
          (d['description'] as String?) ?? '',
          d['date'] != null ? DateFormat('yyyy-MM-dd').format((d['date'] as Timestamp).toDate()) : '',
          (d['time'] as String?) ?? '',
          (d['location'] as String?) ?? '',
          (d['status'] as String?) ?? 'pending',
          (d['submittedByEmail'] as String?) ?? '',
          d['submittedAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((d['submittedAt'] as Timestamp).toDate()) : '',
        ];
      }).toList();
      
      final pdfBytes = await OrgExportPdf.generateTablePdf(
        title: 'Event Proposals Report',
        headers: const [
          'Proposal ID', 'Title', 'Category', 'Audience', 'Description',
          'Date', 'Time', 'Location', 'Status', 'Submitted By', 'Submitted At'
        ],
        rows: rows,
      );
      await OrgExportUtil.saveBytes(pdfBytes, '$fileName.pdf', mimeType: 'application/pdf');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${docs.length} proposals as $format'), backgroundColor: OrgColors.success),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Event Proposals',
              style: GoogleFonts.beVietnamPro(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: OrgColors.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage and submit event proposals for approval',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
            ),
          ]),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _openSubmitModal,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: Text(
              'Submit Proposal',
              style: GoogleFonts.beVietnamPro(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Stats cards
        Row(children: [
          Expanded(child: _StatCard(label: 'Total Proposals', stream: _totalStream, icon: Icons.description_outlined, iconColor: OrgColors.info)),
          const SizedBox(width: 14),
          Expanded(child: _StatCard(label: 'Pending', stream: _pendingStream, icon: Icons.hourglass_empty, iconColor: OrgColors.warning)),
          const SizedBox(width: 14),
          Expanded(child: _StatCard(label: 'Approved', stream: _approvedStream, icon: Icons.check_circle_outline, iconColor: OrgColors.success)),
          const SizedBox(width: 14),
          Expanded(child: _StatCard(label: 'For Review', stream: _forReviewStream, icon: Icons.rate_review_outlined, iconColor: OrgColors.error)),
        ]),
        const SizedBox(height: 24),

        // Main table container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: OrgColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OrgColors.primaryLight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Toolbar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'All Event Proposals',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: OrgColors.charcoal,
                      ),
                    ),
                    Text(
                      'Review and manage your submitted event proposals',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
                    ),
                  ]),
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
                      decoration: InputDecoration(
                        hintText: 'Search proposals...',
                        hintStyle: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
                        prefixIcon: Icon(Icons.search, size: 18, color: OrgColors.darkGray),
                        filled: true,
                        fillColor: OrgColors.lightGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: OrgColors.primaryLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        icon: Icon(Icons.filter_list, size: 16, color: OrgColors.darkGray),
                        style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
                        items: ['All', 'Pending', 'Approved', 'For Review', 'Rejected']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() { _filterStatus = v ?? 'All'; _currentPage = 1; }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AdminExportButton(
                    label: 'Export',
                    onSelected: (format) => _exportProposals(format),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: OrgColors.lightGray,
                  border: Border(
                    top: BorderSide(color: OrgColors.primaryLight),
                    bottom: BorderSide(color: OrgColors.primaryLight),
                  ),
                ),
                child: Row(children: [
                  _headerCell('PROPOSAL #', flex: 2),
                  _headerCell('EVENT TITLE', flex: 4),
                  _headerCell('CATEGORY', flex: 2),
                  _headerCell('AUDIENCE', flex: 2),
                  _headerCell('DATE', flex: 2),
                  _headerCell('LOCATION', flex: 2),
                  _headerCell('STATUS', flex: 2),
                  _headerCell('SUBMITTED', flex: 2),
                  _headerCell('ACTIONS', flex: 2),
                ]),
              ),
              // Table body with pagination
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  key: UniqueKey(),
                  stream: _proposalsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _emptyState();
                    }
                    final filtered = _applyFilters(snapshot.data!.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>().toList());
                    if (filtered.isEmpty) {
                      return _emptyState(message: 'No proposals match your filter.');
                    }
                    final totalPages = (filtered.length / _pageSize).ceil();
                    final safePage = _currentPage.clamp(1, totalPages);
                    final start = (safePage - 1) * _pageSize;
                    final end = (start + _pageSize).clamp(0, filtered.length);
                    final pageItems = filtered.sublist(start, end);
                    
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            itemCount: pageItems.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: OrgColors.mediumGray),
                            itemBuilder: (context, i) {
                              final doc = pageItems[i];
                              final data = doc.data() as Map<String, dynamic>;
                              final proposalNum = 'EP-${doc.id.substring(0, 4).toUpperCase()}';
                              return _ProposalRow(
                                proposalNum: proposalNum,
                                data: data,
                                onEdit: () => _openEditModal(doc.id, data),
                                onDelete: () => _confirmDelete(doc.id, data['title'] ?? 'Proposal'),
                                onView: () => _openViewModal(data),
                              );
                            },
                          ),
                        ),
                        _buildPagination(filtered.length, totalPages, start, end),
                      ],
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          text,
          style: GoogleFonts.beVietnamPro(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: OrgColors.darkGray,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _emptyState({String message = 'No proposals submitted yet.'}) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.description_outlined, size: 56, color: OrgColors.mediumGray),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.beVietnamPro(fontSize: 14, color: OrgColors.darkGray)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openSubmitModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Submit your first proposal', style: GoogleFonts.beVietnamPro(color: Colors.white)),
          ),
        ]),
      );

  Widget _buildPagination(int totalItems, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: OrgColors.primaryLight)),
        color: OrgColors.lightGray,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${totalItems == 0 ? 0 : start + 1}–$end of $totalItems proposals',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
          ),
          Row(children: [
            _PageButton(icon: Icons.chevron_left, enabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumberButton(page: p, isActive: p == _currentPage, onTap: () => setState(() => _currentPage = p))),
            if (lastPage < totalPages) ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray))),
              _PageNumberButton(page: totalPages, isActive: _currentPage == totalPages, onTap: () => setState(() => _currentPage = totalPages)),
            ],
            const SizedBox(width: 4),
            _PageButton(icon: Icons.chevron_right, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
          ]),
        ],
      ),
    );
  }
}

// Small reusable pagination widgets
class _PageButton extends StatelessWidget {
  final IconData icon; final bool enabled; final VoidCallback onTap;
  const _PageButton({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 20, color: enabled ? OrgColors.charcoal : OrgColors.darkGray.withOpacity(0.5))),
      );
}

class _PageNumberButton extends StatelessWidget {
  final int page; final bool isActive; final VoidCallback onTap;
  const _PageNumberButton({required this.page, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: isActive ? OrgColors.primaryDark : Colors.transparent, borderRadius: BorderRadius.circular(6)),
          child: Text('$page', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal, color: isActive ? Colors.white : OrgColors.charcoal)),
        ),
      );
}

// ============ STAT CARD ============
class _StatCard extends StatelessWidget {
  final String label;
  final Stream<QuerySnapshot> stream;
  final IconData icon;
  final Color iconColor;
  const _StatCard({required this.label, required this.stream, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OrgColors.primaryLight),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                count.toString(),
                style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: OrgColors.charcoal),
              ),
              Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
            ]),
          ]),
        );
      },
    );
  }
}

// ============ PROPOSAL ROW ============
class _ProposalRow extends StatelessWidget {
  final String proposalNum;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onView;

  const _ProposalRow({
    required this.proposalNum,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) return DateFormat('MMM dd, yyyy').format(ts.toDate());
    return ts.toString();
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final audience = data['audience'] ?? 'Public';
    return InkWell(
      onTap: onView,
      hoverColor: OrgColors.lightGray,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          Expanded(flex: 2, child: Text(proposalNum, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.primaryDark))),
          Expanded(flex: 4, child: Text(data['title'] ?? '—', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: OrgColors.charcoal), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _categoryChip(data['category'] ?? '—')),
          Expanded(flex: 2, child: _audienceChip(audience)),
          Expanded(flex: 2, child: Text(_formatDate(data['date']), style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray))),
          Expanded(flex: 2, child: Text(data['location'] ?? '—', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _StatusChip(status: status)),
          Expanded(flex: 2, child: Text(_formatDate(data['submittedAt']), style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray))),
          Expanded(flex: 2, child: Row(children: [
            _actionIcon(Icons.visibility_outlined, OrgColors.info, 'View', onView),
            const SizedBox(width: 6),
            _actionIcon(Icons.edit_outlined, OrgColors.primaryDark, 'Edit', onEdit),
            const SizedBox(width: 6),
            _actionIcon(Icons.delete_outline, OrgColors.error, 'Delete', onDelete),
          ])),
        ]),
      ),
    );
  }

  Widget _categoryChip(String category) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(4), border: Border.all(color: OrgColors.primaryLight)),
        child: Text(category, style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray), overflow: TextOverflow.ellipsis),
      );

  Widget _audienceChip(String audience) {
    Color bgColor;
    if (audience == 'Public') bgColor = OrgColors.success.withOpacity(0.2);
    else if (audience == 'CICT Only') bgColor = OrgColors.info.withOpacity(0.2);
    else bgColor = OrgColors.warning.withOpacity(0.2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(audience, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w500, color: OrgColors.charcoal)),
    );
  }

  Widget _actionIcon(IconData icon, Color color, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 18, color: color))),
      );
}

// ============ STATUS CHIP ============
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'approved': bg = OrgColors.success.withOpacity(0.12); fg = OrgColors.success; label = 'Approved'; break;
      case 'rejected': bg = OrgColors.error.withOpacity(0.12); fg = OrgColors.error; label = 'Rejected'; break;
      case 'for_review': bg = OrgColors.info.withOpacity(0.12); fg = OrgColors.info; label = 'For Review'; break;
      default: bg = OrgColors.warning.withOpacity(0.15); fg = const Color(0xFFB45309); label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ============ SUBMIT / EDIT PROPOSAL MODAL ============
class _SubmitProposalModal extends StatefulWidget {
  final String orgId;
  final String? editDocId;
  final Map<String, dynamic>? existing;
  const _SubmitProposalModal({required this.orgId, this.editDocId, this.existing});

  @override
  State<_SubmitProposalModal> createState() => _SubmitProposalModalState();
}

class _SubmitProposalModalState extends State<_SubmitProposalModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _dateCtrl     = TextEditingController();
  final _timeCtrl     = TextEditingController();

  String _selectedCategory = 'Workshop';
  String _selectedAudience = 'Public';
  bool _isSubmitting = false;

  String? _attachmentUrl;
  String? _newAttachmentUrl;
  String? _uploadedFileName;
  String? _uploadedFileSize;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  UploadTask? _uploadTask;
  Timer? _progressTimer;
  StreamSubscription<TaskSnapshot>? _uploadSub;

  static const _categories = [
    'Workshop', 'Seminar', 'Competition', 'General Assembly',
    'Social', 'Outreach', 'Sports', 'Academic', 'Technical', 
    'Cultural', 'Other',
  ];
  static const _audienceOptions = ['Public', 'CICT Only', 'Members Only'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text    = e['title'] ?? '';
      _descCtrl.text     = e['description'] ?? '';
      _locationCtrl.text = e['location'] ?? '';
      _timeCtrl.text     = e['time'] ?? '';
      _attachmentUrl     = e['attachmentUrl'];
      if (e['date'] is Timestamp) {
        _dateCtrl.text = DateFormat('MM/dd/yyyy').format((e['date'] as Timestamp).toDate());
      }
      
      final existingCategory = e['category'] ?? 'Workshop';
      _selectedCategory = _categories.contains(existingCategory) 
          ? existingCategory 
          : 'Workshop';
          
      _selectedAudience = e['audience'] ?? 'Public';
      
      if (_attachmentUrl != null) {
        _uploadedFileName = Uri.decodeFull(_attachmentUrl!.split('/').last.split('?').first);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _progressTimer?.cancel();
    _uploadTask?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png'],
      withData: true,
    );
    
    if (result == null) return;
    final file = result.files.first;

    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot read file! Try another one?')),
        );
      }
      return;
    }

    final fileSizeBytes = file.bytes!.length;
    final maxSize = 700 * 1024;
    
    if (fileSizeBytes > maxSize) {
      final sizeInKB = (fileSizeBytes / 1024).toStringAsFixed(1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File is $sizeInKB KB. Maximum is 700 KB. Please choose a smaller file!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final fileSizeKB = (fileSizeBytes / 1024).toStringAsFixed(1);
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadedFileName = file.name;
      _uploadedFileSize = '$fileSizeKB KB';
    });

    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(Duration(milliseconds: 50));
      if (mounted) {
        setState(() => _uploadProgress = i / 100);
      }
    }

    try {
      String base64String = base64Encode(file.bytes!);
      setState(() {
        _newAttachmentUrl = base64String;
        _uploadProgress = 1.0;
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File ready! Size: $fileSizeKB KB'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error converting file: $e')),
        );
      }
    }
  }

  void _cancelUpload() {
    _progressTimer?.cancel();
    _uploadTask?.cancel();
    _uploadSub?.cancel();
    _uploadSub = null;
    _resetUploadState();
  }

  void _resetUploadState() {
    setState(() {
      _isUploading      = false;
      _uploadProgress   = 0.0;
      _uploadedFileName = null;
      _uploadedFileSize = null;
      _newAttachmentUrl = null;
    });
  }

  void _removeFile() {
    setState(() {
      _newAttachmentUrl = null;
      _attachmentUrl    = null;
      _uploadedFileName = null;
      _uploadedFileSize = null;
      _uploadProgress   = 0.0;
    });
  }

  String _uploadedSoFar() {
    if (_uploadedFileSize == null) return '';
    final isMB  = _uploadedFileSize!.contains('MB');
    final total = double.tryParse(_uploadedFileSize!.split(' ').first) ?? 0;
    final done  = total * _uploadProgress;
    return isMB
        ? '${done.toStringAsFixed(2)} MB'
        : '${done.toStringAsFixed(1)} KB';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.editDocId == null && _newAttachmentUrl == null && _attachmentUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a file before submitting!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    
    String orgName = '';
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final orgQuery = await FirebaseFirestore.instance
            .collection('organizations')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();
        
        if (orgQuery.docs.isNotEmpty) {
          orgName = orgQuery.docs.first.data()['name'] ?? 'Unknown';
        } else {
          final orgDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.orgId)
              .get();
          if (orgDoc.exists) {
            orgName = orgDoc.data()?['name'] ?? 'Unknown';
          }
        }
      }
    } catch (e) {
      orgName = 'Unknown';
    }
    
    final Map<String, dynamic> payload = {
      'orgId': widget.orgId,
      'orgName': orgName,
      'title': _titleCtrl.text.trim(),
      'category': _selectedCategory,
      'audience': _selectedAudience,
      'description': _descCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'time': _timeCtrl.text.trim(),
      'submittedBy': user?.uid ?? '',
      'submittedByEmail': user?.email ?? '',
      'attachmentBase64': _newAttachmentUrl ?? _attachmentUrl,
      'attachmentName': _uploadedFileName,
      'attachmentSize': _uploadedFileSize,
    };

    try {
      final parsed = DateFormat('MM/dd/yyyy').parse(_dateCtrl.text.trim());
      payload['date'] = Timestamp.fromDate(parsed);
    } catch (_) {}

    try {
      if (widget.editDocId != null) {
        await FirebaseFirestore.instance
            .collection('event_proposals')
            .doc(widget.editDocId)
            .update(payload);
      } else {
        payload['status'] = 'pending';
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['submittedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('event_proposals').add(payload);
      }
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal submitted successfully!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editDocId != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(children: [
                Icon(Icons.description_outlined, color: OrgColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isEdit ? 'Edit Event Proposal' : 'Submit Event Proposal',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OrgColors.charcoal,
                      ),
                    ),
                    Text(
                      'Fill in the event details and attach required documents for approval',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray),
                    ),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: _fieldLabel(
                        'Event Title *',
                        child: _textField(
                          _titleCtrl,
                          'e.g. Flutter Workshop 2025',
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _fieldLabel(
                        'Category *',
                        child: _dropdownField(
                          _categories,
                          _selectedCategory,
                          (v) => setState(() => _selectedCategory = v!),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _fieldLabel(
                    'Audience *',
                    child: _dropdownField(
                      _audienceOptions,
                      _selectedAudience,
                      (v) => setState(() => _selectedAudience = v!),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(
                    'Description *',
                    child: _textField(
                      _descCtrl,
                      'Describe your event...',
                      maxLines: 3,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _fieldLabel(
                        'Date *',
                        child: _textField(
                          _dateCtrl,
                          'MM/DD/YYYY',
                          suffix: Icons.calendar_today_outlined,
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              _dateCtrl.text = DateFormat('MM/dd/yyyy').format(picked);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _fieldLabel(
                        'Time *',
                        child: _textField(
                          _timeCtrl,
                          '-- : --',
                          suffix: Icons.access_time,
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null && mounted) {
                              _timeCtrl.text = picked.format(context);
                            }
                          },
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _fieldLabel(
                    'Location *',
                    child: _textField(
                      _locationCtrl,
                      'e.g. IT Building Room 301',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(
                    'File Attachment${isEdit ? '' : ' *'}',
                    child: _fileAttachArea(),
                  ),
                ]),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: BorderSide(color: OrgColors.primaryLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrgColors.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEdit ? 'Save Changes' : 'Submit Proposal',
                          style: GoogleFonts.beVietnamPro(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fileAttachArea() {
    final hasFile = (_newAttachmentUrl != null || _attachmentUrl != null);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OrgColors.lightGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isUploading
              ? OrgColors.primaryDark.withOpacity(0.4)
              : hasFile
                  ? OrgColors.success
                  : OrgColors.mediumGray,
          width: _isUploading || hasFile ? 1.5 : 1,
        ),
      ),
      child: _isUploading
          ? _uploadingState()
          : hasFile
              ? _uploadedState()
              : _idleState(),
    );
  }

  Widget _idleState() {
    return GestureDetector(
      onTap: _pickAndUploadFile,
      behavior: HitTestBehavior.opaque,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: OrgColors.primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.cloud_upload_outlined, size: 22, color: OrgColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
              children: [
                TextSpan(
                  text: 'Click to upload ',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: OrgColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: 'proposal documents'),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'PDF, DOC, DOCX, TXT, JPG, PNG — max 700 KB',
            style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray),
          ),
        ]),
      ]),
    );
  }

  Widget _uploadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: OrgColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.insert_drive_file_outlined, size: 16, color: OrgColors.primaryDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _uploadedFileName ?? 'Uploading...',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: OrgColors.charcoal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _uploadedFileSize ?? '',
            style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _cancelUpload,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: OrgColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.close, size: 14, color: OrgColors.error),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            minHeight: 6,
            backgroundColor: OrgColors.mediumGray,
            valueColor: AlwaysStoppedAnimation<Color>(OrgColors.primaryDark),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text(
            'Uploading ${(_uploadProgress * 100).clamp(0, 100).toInt()}%',
            style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray),
          ),
          const Spacer(),
          Text(
            '${_uploadedSoFar()} / ${_uploadedFileSize ?? ''}',
            style: GoogleFonts.beVietnamPro(
              fontSize: 10,
              color: OrgColors.primaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _uploadedState() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: OrgColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.check_circle, size: 18, color: OrgColors.success),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _uploadedFileName ?? 'File attached',
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: OrgColors.charcoal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (_uploadedFileSize != null)
            Text(
              _uploadedFileSize!,
              style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.success),
            ),
        ]),
      ),
      TextButton(
        onPressed: _removeFile,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Remove',
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.error),
        ),
      ),
      const SizedBox(width: 4),
      TextButton(
        onPressed: _pickAndUploadFile,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Change',
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.primaryDark),
        ),
      ),
    ]);
  }

  Widget _fieldLabel(String label, {required Widget child}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: OrgColors.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ]);

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    IconData? suffix,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        readOnly: onTap != null,
        onTap: onTap,
        validator: validator,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
          filled: true,
          fillColor: OrgColors.lightGray,
          suffixIcon: suffix != null ? Icon(suffix, size: 16, color: OrgColors.darkGray) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OrgColors.primaryLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OrgColors.primaryLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OrgColors.primaryDark, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OrgColors.error),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: maxLines > 1 ? 10 : 0,
          ),
        ),
      );

  Widget _dropdownField(
    List<String> items,
    String currentValue,
    ValueChanged<String?> onChanged,
  ) {
    String safeValue = items.contains(currentValue) ? currentValue : items.first;
    
    if (safeValue != currentValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onChanged(safeValue);
      });
    }
    
    return DropdownButtonFormField<String>(
      value: safeValue,
      items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: onChanged,
      style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
      decoration: InputDecoration(
        filled: true,
        fillColor: OrgColors.lightGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: OrgColors.primaryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: OrgColors.primaryLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: OrgColors.primaryDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
}

// ============ VIEW PROPOSAL MODAL ============
class _ViewProposalModal extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ViewProposalModal({required this.data});

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) return DateFormat('MMMM dd, yyyy').format(ts.toDate());
    return ts.toString();
  }

  static String _getMimeFromExtension(String ext) {
    switch (ext) {
      case 'txt': return 'text/plain';
      case 'md': return 'text/markdown';
      case 'json': return 'application/json';
      case 'html': case 'htm': return 'text/html';
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'gif': return 'image/gif';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'csv': return 'text/csv';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final audience = data['audience'] ?? 'Public';
    
    final hasBase64 = data['attachmentBase64'] != null && data['attachmentBase64'].toString().isNotEmpty;
    final hasUrl = data['attachmentUrl'] != null && data['attachmentUrl'].toString().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: OrgColors.lightGray,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
            ),
            child: Row(children: [
              Icon(Icons.description_outlined, color: OrgColors.primaryDark, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['title'] ?? 'Proposal Details',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OrgColors.charcoal,
                  ),
                ),
              ),
              _StatusChip(status: status),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _detailRow('Category', data['category'] ?? '—'),
                _detailRow('Audience', audience),
                _detailRow('Description', data['description'] ?? '—'),
                _detailRow('Date', _formatDate(data['date'])),
                _detailRow('Time', data['time'] ?? '—'),
                _detailRow('Location', data['location'] ?? '—'),
                _detailRow('Submitted', _formatDate(data['submittedAt'])),
                
                if (hasBase64 || hasUrl) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Attachment', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: OrgColors.primaryDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.insert_drive_file, size: 20, color: OrgColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['attachmentName'] ?? 'Attached File',
                            style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (data['attachmentSize'] != null)
                            Text(data['attachmentSize'], style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAttachment(context, data),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('View'),
                      style: TextButton.styleFrom(foregroundColor: OrgColors.primaryDark),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: OrgColors.primaryLight))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrgColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Close', style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _openAttachment(BuildContext context, Map<String, dynamic> data) {
    final hasBase64 = data['attachmentBase64'] != null && data['attachmentBase64'].toString().isNotEmpty;
    final hasUrl = data['attachmentUrl'] != null && data['attachmentUrl'].toString().isNotEmpty;

    if (!hasBase64 && !hasUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachment found')),
      );
      return;
    }

    _handleAndPreviewAttachment(context, data, hasBase64: hasBase64, hasUrl: hasUrl);
  }

  Future<void> _handleAndPreviewAttachment(BuildContext context, Map<String, dynamic> data, 
      {required bool hasBase64, required bool hasUrl}) async {
    try {
      Uint8List bytes = Uint8List(0);
      String fileName = data['attachmentName'] ?? 'document';

      if (hasBase64) {
        final String base64String = data['attachmentBase64'];
        bytes = base64Decode(base64String);
      } else if (hasUrl) {
        final String url = data['attachmentUrl'];
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          bytes = await ref.getData(50 * 1024 * 1024) ?? Uint8List(0);
        } catch (_) {
          try {
            final uri = Uri.parse(url);
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              bytes = response.bodyBytes;
            }
          } catch (e) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Open Attachment'),
                  content: Text('Cannot download attachment. Open in browser instead?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        platform_file_utils.openUrl(url);
                      },
                      child: const Text('Open'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        }
      }

      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empty attachment')));
        }
        return;
      }

      final ext = (fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '');
      final mime = _getMimeFromExtension(ext);

      if (mime.startsWith('text/')) {
        final content = utf8.decode(bytes);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(fileName),
              content: SingleChildScrollView(child: SelectableText(content)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
                  },
                  child: const Text('Download'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mime.startsWith('image/')) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(fileName, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                ),
                Flexible(child: Image.memory(bytes)),
                ButtonBar(children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
                    },
                    child: const Text('Download'),
                  ),
                ])
              ]),
            ),
          );
        }
        return;
      }

      await platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening attachment: $e')));
      }
    }
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100, child: Text('$label:', 
        style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray))),
      Expanded(child: Text(value, 
        style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal))),
    ]),
  );
}