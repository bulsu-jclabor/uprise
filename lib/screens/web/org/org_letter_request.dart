// lib/screens/web/org/org_letter_request.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../widgets/admin_export_button.dart';
import 'export_util.dart';
import 'export_pdf.dart';

// ============ COLOR SCHEME ============
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color accentBg     = Color(0xFFFEF3C7);
  static const Color accentText   = Color(0xFF92400E);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF16A34A);
  static const Color successBg    = Color(0xFFDCFCE7);
  static const Color warning      = Color(0xFFB45309);
  static const Color warningBg    = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color info         = Color(0xFF2563EB);
  static const Color infoBg       = Color(0xFFEFF6FF);
  static const Color purple       = Color(0xFF7C3AED);
  static const Color purpleBg     = Color(0xFFF3E8FF);
  static const Color reviewColor  = Color(0xFF5B21B6);
  static const Color reviewBg     = Color(0xFFEDE9FE);
}

// ============ MAIN SCREEN ============
class OrgLetterRequestScreen extends StatefulWidget {
  final String orgId;
  const OrgLetterRequestScreen({super.key, required this.orgId});

  @override
  State<OrgLetterRequestScreen> createState() => _OrgLetterRequestScreenState();
}

class _OrgLetterRequestScreenState extends State<OrgLetterRequestScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  
  Map<String, dynamic>? _orgProfile;
  String _orgName = '';
  String _orgEmail = '';

  @override
  void initState() {
    super.initState();
    _loadOrgProfile();
  }

  Future<void> _loadOrgProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .get();
      if (doc.exists) {
        setState(() {
          _orgProfile = doc.data();
          _orgName = doc.data()?['name'] ?? 'Organization';
          _orgEmail = doc.data()?['email'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading org profile: $e');
    }
  }

  Stream<QuerySnapshot> get _requestsStream => FirebaseFirestore.instance
      .collection('letter_requests')
      .where('orgId', isEqualTo: widget.orgId)
      .where('isArchived', isEqualTo: false)  // Only show non-archived
      .orderBy('timestamp', descending: true)
      .snapshots();

  Future<void> _openNewRequestModal() async {
    if (_orgProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading organization info...')),
      );
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LetterRequestModal(
        orgId: widget.orgId,
        orgName: _orgName,
        orgEmail: _orgEmail,
      ),
    );
  }

  Future<void> _openEditRequestModal(LetterRequestModel request) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LetterRequestModal(
        orgId: widget.orgId,
        orgName: _orgName,
        orgEmail: _orgEmail,
        existingRequest: request,
      ),
    );
  }

  Future<void> _viewRequestDetails(LetterRequestModel request) async {
    await showDialog(
      context: context,
      builder: (_) => _RequestDetailsDialog(request: request),
    );
  }

  Future<void> _archiveRequest(LetterRequestModel request) async {
    final confirm = await _showConfirmDialog(
      title: 'Archive Request',
      message: 'Archive request "${request.subject}"? You can still view it in archived section.',
      confirmLabel: 'Archive',
      isDestructive: false,
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('letter_requests').doc(request.id).update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });
      await activity_log.ActivityLogger.log(
        action: 'archive_letter_request',
        module: 'letter_request',
        details: {'orgId': widget.orgId, 'requestId': request.id},
      );
      _showSnack('Request archived successfully');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

<<<<<<< HEAD
  Future<void> _updateStatus(LetterRequestModel request, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('letter_requests').doc(request.id).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await activity_log.ActivityLogger.log(
        action: 'update_letter_status',
        module: 'letter_request',
        details: {'orgId': widget.orgId, 'requestId': request.id, 'status': newStatus},
      );
      _showSnack('Status updated to ${newStatus[0].toUpperCase()}${newStatus.substring(1)}');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _exportLetters(String choice, List<LetterRequestModel> filtered) async {
    if (filtered.isEmpty) {
      _showSnack('No records to export', isError: true);
      return;
    }

    final headers = ['Letter ID', 'Name', 'Email', 'Letter Type', 'Subject', 'Date Submitted', 'Status', 'Replied'];
    final rows = filtered.map((r) => [
          r.letterId,
          r.name,
          r.email,
          r.letterType,
          r.subject,
          DateFormat('yyyy-MM-dd').format(r.timestamp.toDate()),
          r.status,
          r.replied ? 'Yes' : 'No',
        ]).toList();

    try {
      if (choice == 'csv') {
        final csv = [headers, ...rows]
            .map((row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
            .join('\n');
        await OrgExportUtil.saveText(csv, 'letter_requests_${DateTime.now().millisecondsSinceEpoch}.csv', mimeType: 'text/csv');
      } else if (choice == 'pdf') {
        final pdfBytes = await OrgExportPdf.generateTablePdf(
          title: 'Letter Requests',
          headers: headers,
          rows: rows,
        );
        await OrgExportUtil.saveBytes(pdfBytes, 'letter_requests_${DateTime.now().millisecondsSinceEpoch}.pdf', mimeType: 'application/pdf');
      }
      _showSnack('Exported ${filtered.length} records', isError: false);
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    }
  }

=======
>>>>>>> a3d3a25182ba5d8737adf84eb3fadcff242bf2f5
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro(color: Colors.white)),
      backgroundColor: isError ? OrgColors.error : OrgColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24)],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: isDestructive ? OrgColors.errorBg : OrgColors.accentBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive ? Icons.delete_outline : Icons.archive_outlined,
                  color: isDestructive ? OrgColors.error : OrgColors.primaryDark,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      backgroundColor: isDestructive ? OrgColors.error : OrgColors.primaryDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(confirmLabel, style: GoogleFonts.beVietnamPro(color: Colors.white)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
<<<<<<< HEAD
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: StreamBuilder<QuerySnapshot>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        // 🔴 ADDED: Show error if any
        if (snapshot.hasError) {
          print('ERROR in letter requests stream: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: OrgColors.error),
                const SizedBox(height: 12),
                Text(
                  'Error loading requests: ${snapshot.error}',
                  style: GoogleFonts.beVietnamPro(color: OrgColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // 🔴 ADDED: Show loading properly
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 🔴 ADDED: Safe check for data
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 48, color: OrgColors.mediumGray),
                const SizedBox(height: 12),
                Text(
                  'No letter requests yet',
                  style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Click "New Request" to create one',
                  style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // 🔴 CHANGED: Wrap in try-catch for conversion errors
        List<LetterRequestModel> allRequests = [];
        try {
          allRequests = snapshot.data!.docs.map((d) {
            try {
              return LetterRequestModel.fromFirestore(d);
            } catch (e, stacktrace) {
              print('Error converting document ${d.id}: $e');
              print('Stacktrace: $stacktrace');
              // Return a default model to prevent crash
              return LetterRequestModel(
                id: d.id,
                letterId: 'ERROR',
                name: 'Error loading',
                email: '',
                letterType: '',
                subject: '',
                message: '',
                status: 'pending',
                replied: false,
                timestamp: Timestamp.now(),
                repliedAt: null,
              );
            }
          }).toList();
        } catch (e) {
          print('Error mapping documents: $e');
          return Center(
            child: Text('Error loading data: $e', style: GoogleFonts.beVietnamPro(color: OrgColors.error)),
          );
        }

        final filtered = _applyFilters(allRequests);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(filtered),
            const SizedBox(height: 20),
            _buildStats(allRequests),
            const SizedBox(height: 20),
            Expanded(child: _buildTableCard(allRequests, filtered, snapshot)),
          ],
        );
      },
    ),
  );
}

  Widget _buildHeader(List<LetterRequestModel> filtered) {
    return Row(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Letter Request',
              style: GoogleFonts.beVietnamPro(fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
          const SizedBox(height: 2),
          Text('Create and manage professional letter requests',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
        ]),
        const Spacer(),
        AdminExportButton(
          label: 'Export',
          onSelected: (choice) => _exportLetters(choice, filtered),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _openNewRequestModal,
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: Text('New Request',
              style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: OrgColors.primaryDark,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(List<LetterRequestModel> all) {
    final pending  = all.where((r) => r.status == 'pending').length;
    final replied  = all.where((r) => r.replied).length;
    final types    = all.map((r) => r.letterType).toSet().length;

    return Row(children: [
      _StatCard(label: 'Total Requests',   value: all.length,  icon: Icons.mail_outline,     iconBg: OrgColors.infoBg,   iconColor: OrgColors.info),
      const SizedBox(width: 12),
      _StatCard(label: 'Pending Reply',    value: pending,     icon: Icons.hourglass_empty,  iconBg: OrgColors.warningBg, iconColor: OrgColors.warning),
      const SizedBox(width: 12),
      _StatCard(label: 'Replied',          value: replied,     icon: Icons.done_all,         iconBg: OrgColors.successBg, iconColor: OrgColors.success),
      const SizedBox(width: 12),
      _StatCard(label: 'Letter Types Used',value: types,       icon: Icons.category_outlined, iconBg: OrgColors.purpleBg, iconColor: OrgColors.purple),
    ]);
  }

  Widget _buildTableCard(
    List<LetterRequestModel> all,
    List<LetterRequestModel> filtered,
    AsyncSnapshot<QuerySnapshot> snapshot,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight, width: 0.5),
      ),
=======
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
>>>>>>> a3d3a25182ba5d8737adf84eb3fadcff242bf2f5
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatsRow(),
          const SizedBox(height: 24),
          Expanded(child: _buildTable()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Letter Request',
            style: GoogleFonts.beVietnamPro(fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
        const SizedBox(height: 2),
        Text('Create and manage letter requests',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
      ]),
      const Spacer(),
      ElevatedButton.icon(
        onPressed: _openNewRequestModal,
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: Text('New Request',
            style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: OrgColors.primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]);
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0, revision = 0, resubmitted = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            total++;
            final status = (doc.data() as Map)['status'] ?? 'pending';
            if (status == 'pending') pending++;
            if (status == 'approved') approved++;
            if (status == 'rejected') rejected++;
            if (status == 'revision') revision++;
            if (status == 'resubmitted') resubmitted++;
          }
        }
        return Row(children: [
          _StatCard(label: 'Total Requests', value: total, icon: Icons.description_outlined, color: OrgColors.info),
          const SizedBox(width: 14),
          _StatCard(label: 'Pending', value: pending, icon: Icons.pending_outlined, color: OrgColors.warning),
          const SizedBox(width: 14),
          _StatCard(label: 'Approved', value: approved, icon: Icons.check_circle_outline, color: OrgColors.success),
          const SizedBox(width: 14),
          _StatCard(label: 'Rejected', value: rejected, icon: Icons.cancel_outlined, color: OrgColors.error),
          const SizedBox(width: 14),
          _StatCard(label: 'Resubmitted', value: resubmitted, icon: Icons.refresh_rounded, color: OrgColors.purple),
          const SizedBox(width: 14),
          _StatCard(label: 'Needs Revision', value: revision, icon: Icons.edit_note_rounded, color: OrgColors.info),
        ]);
      },
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data!.docs;
        
        if (_statusFilter != 'All') {
          docs = docs.where((d) => (d.data() as Map)['status'] == _statusFilter.toLowerCase()).toList();
        }
        
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['letterId'] ?? '').toString().toLowerCase().contains(term) ||
                   (data['subject'] ?? '').toString().toLowerCase().contains(term);
          }).toList();
        }

        final requests = docs.map((d) => LetterRequestModel.fromFirestore(d)).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OrgColors.primaryLight, width: 0.5),
          ),
          child: Column(
            children: [
              _buildToolbar(),
              const Divider(height: 0),
              Expanded(
                child: requests.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 48,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 72,
                          headingRowColor: WidgetStateProperty.all(OrgColors.lightGray),
                          columns: const [
                            DataColumn(label: Text('LETTER ID')),
                            DataColumn(label: Text('SUBJECT')),
                            DataColumn(label: Text('DATE SUBMITTED')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: requests.map((req) => DataRow(cells: [
                            DataCell(
                              InkWell(
                                onTap: () => _viewRequestDetails(req),
                                child: Text(req.letterId,
                                    style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.primaryDark)),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => _viewRequestDetails(req),
                                child: Text(req.subject,
                                    style: GoogleFonts.beVietnamPro(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => _viewRequestDetails(req),
                                child: Text(DateFormat('MMM dd, yyyy').format(req.timestamp.toDate()),
                                    style: GoogleFonts.beVietnamPro(fontSize: 12)),
                              ),
                            ),
                            DataCell(_buildStatusBadge(req.status, req.revisionNote)),
                            DataCell(Row(children: [
                              // VIEW button - always visible
                              _ActionIconButton(
                                icon: Icons.visibility_outlined,
                                tooltip: 'View Details',
                                color: OrgColors.primaryDark,
                                onTap: () => _viewRequestDetails(req),
                              ),
                              const SizedBox(width: 4),
                              // Info button for revision notes (only for revision status)
                              if (req.status == 'revision')
                                _ActionIconButton(
                                  icon: Icons.info_outline,
                                  tooltip: 'View Revision Notes',
                                  color: OrgColors.info,
                                  onTap: () => _viewRequestDetails(req),
                                ),
                              // Edit button - available for pending, revision, and resubmitted only
                              if (req.status == 'pending' || req.status == 'revision' || req.status == 'resubmitted')
                                _ActionIconButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: 'Edit',
                                  color: OrgColors.info,
                                  onTap: () => _openEditRequestModal(req),
                                ),
                              // ARCHIVE button - instead of delete
                              _ActionIconButton(
                                icon: Icons.archive_outlined,
                                tooltip: 'Archive',
                                color: OrgColors.warning,
                                onTap: () => _archiveRequest(req),
                              ),
                            ])),
                          ])).toList(),
                        ),
                      ),
              ),
              _buildFooter(requests.length),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        SizedBox(
          width: 280,
          height: 38,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.beVietnamPro(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by ID or subject...',
              hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
              prefixIcon: const Icon(Icons.search, size: 18, color: OrgColors.darkGray),
              filled: true,
              fillColor: OrgColors.lightGray,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    })
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _FilterChip(
          label: 'All',
          selected: _statusFilter == 'All',
          onTap: () => setState(() => _statusFilter = 'All'),
        ),
        _FilterChip(
          label: 'Pending',
          selected: _statusFilter == 'Pending',
          onTap: () => setState(() => _statusFilter = 'Pending'),
        ),
        _FilterChip(
          label: 'Approved',
          selected: _statusFilter == 'Approved',
          onTap: () => setState(() => _statusFilter = 'Approved'),
        ),
        _FilterChip(
          label: 'Rejected',
          selected: _statusFilter == 'Rejected',
          onTap: () => setState(() => _statusFilter = 'Rejected'),
        ),
        _FilterChip(
          label: 'Resubmitted',
          selected: _statusFilter == 'Resubmitted',
          onTap: () => setState(() => _statusFilter = 'Resubmitted'),
        ),
        _FilterChip(
          label: 'Needs Revision',
          selected: _statusFilter == 'Needs Revision',
          onTap: () => setState(() => _statusFilter = 'Needs Revision'),
        ),
      ]),
    );
  }

  Widget _buildFooter(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: OrgColors.primaryLight, width: 0.5)),
        color: OrgColors.lightGray,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Showing $total requests', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.mail_outline, size: 48, color: OrgColors.mediumGray),
        const SizedBox(height: 12),
        Text('No letter requests',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: OrgColors.darkGray)),
        const SizedBox(height: 6),
        Text('Click "New Request" to create one',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
      ]),
    );
  }

  Widget _buildStatusBadge(String status, String? revisionNote) {
    Map<String, dynamic> style;
    switch (status.toLowerCase()) {
      case 'approved':
        style = {'bg': OrgColors.successBg, 'fg': OrgColors.success, 'label': 'Approved'};
        break;
      case 'rejected':
        style = {'bg': OrgColors.errorBg, 'fg': OrgColors.error, 'label': 'Rejected'};
        break;
      case 'revision':
        style = {'bg': OrgColors.infoBg, 'fg': OrgColors.info, 'label': 'Needs Revision'};
        break;
      case 'resubmitted':
        style = {'bg': OrgColors.purpleBg, 'fg': OrgColors.purple, 'label': 'Resubmitted'};
        break;
      default:
        style = {'bg': OrgColors.warningBg, 'fg': OrgColors.warning, 'label': 'Pending'};
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: style['bg'], borderRadius: BorderRadius.circular(20)),
          child: Text(style['label'], style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: style['fg'])),
        ),
        if (revisionNote != null && status == 'revision')
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.info_outline, size: 14, color: OrgColors.info),
          ),
      ],
    );
  }
}

// ============ STAT CARD ============
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OrgColors.primaryLight, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value', style: GoogleFonts.beVietnamPro(fontSize: 26, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
          ]),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: selected ? OrgColors.primaryDark : OrgColors.lightGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? OrgColors.primaryDark : OrgColors.mediumGray),
        ),
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : OrgColors.darkGray,
            )),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionIconButton({required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18, color: color)),
      ),
    );
  }
}

// ============ REQUEST DETAILS DIALOG ============
class _RequestDetailsDialog extends StatelessWidget {
  final LetterRequestModel request;

  const _RequestDetailsDialog({required this.request});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: OrgColors.accentBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.description_outlined, color: OrgColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Request Details', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(request.letterId, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
              ),
            ]),
            const SizedBox(height: 20),
            _infoRow('Subject', request.subject),
            const SizedBox(height: 12),
            _infoRow('Status', _getStatusDisplay(request.status)),
            if (request.revisionNote != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OrgColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OrgColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REVISION NOTE', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: OrgColors.info)),
                    const SizedBox(height: 6),
                    Text(request.revisionNote!, style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal)),
                  ],
                ),
              ),
            ],
            if (request.revisionCount != null && request.revisionCount! > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OrgColors.mediumGray.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.history, size: 16, color: OrgColors.darkGray),
                  const SizedBox(width: 8),
                  Text('Revision #${request.revisionCount}',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            _infoRow('Date Submitted', DateFormat('MMM dd, yyyy hh:mm a').format(request.timestamp.toDate())),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      case 'revision': return 'NEEDS REVISION';
      case 'resubmitted': return 'RESUBMITTED';
      default: return 'PENDING';
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text('$label:', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray))),
        Expanded(child: Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal))),
      ],
    );
  }
}

// ============ LETTER REQUEST MODAL ============
class _LetterRequestModal extends StatefulWidget {
  final String orgId;
  final String orgName;
  final String orgEmail;
  final LetterRequestModel? existingRequest;

  const _LetterRequestModal({
    required this.orgId,
    required this.orgName,
    required this.orgEmail,
    this.existingRequest,
  });

  @override
  State<_LetterRequestModal> createState() => _LetterRequestModalState();
}

class _LetterRequestModalState extends State<_LetterRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();

  String? _attachmentBase64;
  String? _attachmentName;
  String? _attachmentSize;
  bool _isSubmitting = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRequest;
    if (r != null) {
      _subjectCtrl.text = r.subject;
      _attachmentBase64 = r.attachmentBase64;
      _attachmentName = r.attachmentName;
      _attachmentSize = r.attachmentSize;
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
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
      _showMessage('Cannot read file!', isError: true);
      return;
    }

    final fileSizeBytes = file.bytes!.length;
    final maxSize = 700 * 1024;
    
    if (fileSizeBytes > maxSize) {
      final sizeInKB = (fileSizeBytes / 1024).toStringAsFixed(1);
      _showMessage('File is $sizeInKB KB. Maximum is 700 KB!', isError: true);
      return;
    }

    final fileSizeKB = (fileSizeBytes / 1024).toStringAsFixed(1);
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _attachmentName = file.name;
      _attachmentSize = '$fileSizeKB KB';
    });

    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) setState(() => _uploadProgress = i / 100);
    }

    try {
      String base64String = base64Encode(file.bytes!);
      setState(() {
        _attachmentBase64 = base64String;
        _uploadProgress = 1.0;
        _isUploading = false;
      });
      _showMessage('File ready! Size: $fileSizeKB KB');
    } catch (e) {
      setState(() => _isUploading = false);
      _showMessage('Error converting file: $e', isError: true);
    }
  }

  void _removeFile() {
    setState(() {
      _attachmentBase64 = null;
      _attachmentName = null;
      _attachmentSize = null;
      _uploadProgress = 0.0;
    });
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  
  if (widget.existingRequest == null && _attachmentBase64 == null) {
    _showMessage('Please attach a file before submitting!', isError: true);
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    final Map<String, dynamic> data = {
      'orgId': widget.orgId,
      'orgName': widget.orgName,
      'orgEmail': widget.orgEmail,
      'subject': _subjectCtrl.text.trim(),
      'attachmentBase64': _attachmentBase64,
      'attachmentName': _attachmentName,
      'attachmentSize': _attachmentSize,
      'updatedAt': FieldValue.serverTimestamp(),
      'isArchived': false,
    };

    final col = FirebaseFirestore.instance.collection('letter_requests');
    
    if (widget.existingRequest != null) {
      // EDIT MODE - Update existing document
      final updateData = Map<String, dynamic>.from(data);
      
      if (widget.existingRequest!.status == 'revision') {
        updateData['status'] = 'resubmitted';
        updateData['resubmittedAt'] = FieldValue.serverTimestamp();
        updateData['revisionNote'] = null;
        updateData['revisionCount'] = FieldValue.increment(1);
      }
      
      await col.doc(widget.existingRequest!.id).update(updateData);
      await activity_log.ActivityLogger.log(
        action: 'edit_letter_request',
        module: 'letter_request',
        details: {'orgId': widget.orgId, 'requestId': widget.existingRequest!.id},
      );
      _showMessage('Letter request updated successfully!');
    } else {
      // NEW MODE - Create new document
      final letterId = 'RLR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      data['status'] = 'pending';
      data['letterId'] = letterId;
      data['timestamp'] = FieldValue.serverTimestamp();
      data['revisionCount'] = 0;
      await col.add(data);
      await activity_log.ActivityLogger.log(
        action: 'create_letter_request',
        module: 'letter_request',
        details: {'orgId': widget.orgId, 'subject': data['subject']},
      );
      _showMessage('Letter request submitted successfully!');
    }
    
    if (mounted) Navigator.pop(context);
  } catch (e) {
    _showMessage('Error: $e', isError: true);
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingRequest != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 32)],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: OrgColors.lightGray,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: OrgColors.primaryLight, width: 0.5)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: OrgColors.accentBg, shape: BoxShape.circle),
                    child: const Icon(Icons.mail_outline, color: OrgColors.primaryDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isEdit ? 'Edit Letter Request' : 'New Request',
                          style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Fill in all required fields',
                          style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                    ]),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    splashRadius: 18,
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OrgColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OrgColors.mediumGray),
                      ),
                      child: Row(children: [
                        const Icon(Icons.business_outlined, size: 18, color: OrgColors.primaryDark),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(widget.orgName,
                                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(widget.orgEmail,
                                style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _subjectCtrl,
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'SUBJECT *',
                        hintText: "What's this regarding?",
                        labelStyle: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.darkGray),
                        filled: true,
                        fillColor: OrgColors.lightGray,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: OrgColors.primaryDark, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) => v?.trim().isEmpty == true ? 'Subject is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildFileAttachment(),
                    if (widget.existingRequest?.revisionNote != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: OrgColors.infoBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: OrgColors.info.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REVISION NOTE FROM ADMIN', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: OrgColors.info)),
                            const SizedBox(height: 6),
                            Text(widget.existingRequest!.revisionNote!,
                                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.charcoal)),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: OrgColors.primaryLight, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting || _isUploading ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 16, color: Colors.white),
                      label: Text(isEdit ? 'Save Changes' : 'Submit Request',
                          style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrgColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileAttachment() {
    final hasFile = _attachmentBase64 != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Attachment ${widget.existingRequest == null ? '*' : ''}',
          style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.charcoal),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: OrgColors.lightGray,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isUploading
                  ? OrgColors.primaryDark.withOpacity(0.4)
                  : hasFile ? OrgColors.success : OrgColors.mediumGray,
              width: _isUploading || hasFile ? 1.5 : 1,
            ),
          ),
          child: _isUploading
              ? _buildUploadingState()
              : hasFile ? _buildUploadedState() : _buildIdleState(),
        ),
      ],
    );
  }

  Widget _buildIdleState() {
    return GestureDetector(
      onTap: _pickAndUploadFile,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: OrgColors.primaryDark.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.cloud_upload_outlined, size: 22, color: OrgColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
              children: [
                TextSpan(text: 'Click to upload ', style: GoogleFonts.beVietnamPro(color: OrgColors.primaryDark, fontWeight: FontWeight.w600)),
                const TextSpan(text: 'letter documents'),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text('PDF, DOC, DOCX, TXT, JPG, PNG — max 700 KB',
              style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray)),
        ]),
      ]),
    );
  }

  Widget _buildUploadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: OrgColors.primaryDark.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.insert_drive_file_outlined, size: 16, color: OrgColors.primaryDark),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(_attachmentName ?? 'Uploading...',
              style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          Text(_attachmentSize ?? '', style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: _uploadProgress, minHeight: 6,
              backgroundColor: OrgColors.mediumGray,
              valueColor: const AlwaysStoppedAnimation(OrgColors.primaryDark)),
        ),
        const SizedBox(height: 6),
        Text('Uploading ${(_uploadProgress * 100).toInt()}%',
            style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray)),
      ],
    );
  }

  Widget _buildUploadedState() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: OrgColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.check_circle, size: 18, color: OrgColors.success),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_attachmentName ?? 'File attached',
            style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        if (_attachmentSize != null) Text(_attachmentSize!,
            style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.success)),
      ])),
      TextButton(onPressed: _removeFile, child: Text('Remove', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.error))),
      TextButton(onPressed: _pickAndUploadFile, child: Text('Change', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.primaryDark))),
    ]);
  }
}

// ============ LETTER REQUEST MODEL ============
class LetterRequestModel {
  final String id;
  final String letterId;
  final String orgId;
  final String orgName;
  final String orgEmail;
  final String subject;
  final String? attachmentBase64;
  final String? attachmentName;
  final String? attachmentSize;
  final String status;
  final String? revisionNote;
  final int? revisionCount;
  final Timestamp? resubmittedAt;
  final bool isArchived;
  final Timestamp timestamp;

  LetterRequestModel({
    required this.id,
    required this.letterId,
    required this.orgId,
    required this.orgName,
    required this.orgEmail,
    required this.subject,
    this.attachmentBase64,
    this.attachmentName,
    this.attachmentSize,
    required this.status,
    this.revisionNote,
    this.revisionCount,
    this.resubmittedAt,
    required this.isArchived,
    required this.timestamp,
  });

  factory LetterRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LetterRequestModel(
      id: doc.id,
      letterId: d['letterId'] ?? 'RLR-${doc.id.substring(0, 6)}',
      orgId: d['orgId'] ?? '',
      orgName: d['orgName'] ?? 'Unknown Organization',
      orgEmail: d['orgEmail'] ?? '',
      subject: d['subject'] ?? '',
      attachmentBase64: d['attachmentBase64'],
      attachmentName: d['attachmentName'],
      attachmentSize: d['attachmentSize'],
      status: d['status'] ?? 'pending',
      revisionNote: d['revisionNote'],
      revisionCount: d['revisionCount'] ?? 0,
      resubmittedAt: d['resubmittedAt'] as Timestamp?,
      isArchived: d['isArchived'] ?? false,
      timestamp: d['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}