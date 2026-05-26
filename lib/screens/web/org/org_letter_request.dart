// lib/screens/web/org/org_letter_request.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';  // For Uint8List
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ignore_for_file: use_build_context_synchronously

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

// ============ STATUS ENUM ============
enum LetterStatus { all, pending, approved, rejected, review }

extension LetterStatusExt on LetterStatus {
  String get label {
    switch (this) {
      case LetterStatus.all:      return 'All';
      case LetterStatus.pending:  return 'Pending';
      case LetterStatus.approved: return 'Approved';
      case LetterStatus.rejected: return 'Rejected';
      case LetterStatus.review:   return 'On Review';
    }
  }

  String? get firestoreValue {
    if (this == LetterStatus.all) return null;
    return name;
  }
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
  LetterStatus _activeTab = LetterStatus.all;
  String _typeFilter = '';
  String _sortBy = 'newest';

  static const List<String> _letterTypes = [
    'Recruitment Letter',
    'Appreciation Letter',
    'Permission Letter',
    'Request Letter for Venue',
    'Sponsorship Letter',
    'General Inquiry',
  ];

  Stream<QuerySnapshot> get _requestsStream => FirebaseFirestore.instance
      .collection('letter_requests')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('timestamp', descending: true)
      .snapshots();

  // ---- Filtering & Sorting ----
  List<LetterRequestModel> _applyFilters(List<LetterRequestModel> list) {
    var result = list.where((r) {
      // Tab filter
      if (_activeTab != LetterStatus.all && r.status != _activeTab.firestoreValue) return false;
      // Type filter
      if (_typeFilter.isNotEmpty && r.letterType != _typeFilter) return false;
      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!r.name.toLowerCase().contains(q) &&
            !r.email.toLowerCase().contains(q) &&
            !r.subject.toLowerCase().contains(q) &&
            !r.letterType.toLowerCase().contains(q) &&
            !r.letterId.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'oldest':
        result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'name':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return result;
  }

  int _tabCount(List<LetterRequestModel> all, LetterStatus tab) {
    if (tab == LetterStatus.all) return all.length;
    return all.where((r) => r.status == tab.firestoreValue).length;
  }

  // ---- Actions ----
  Future<void> _openNewRequestModal() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LetterRequestModal(orgId: widget.orgId),
    );
  }

  Future<void> _openEditRequestModal(LetterRequestModel request) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LetterRequestModal(orgId: widget.orgId, existingRequest: request),
    );
  }

  Future<void> _deleteRequest(LetterRequestModel request) async {
  final confirm = await _showConfirmDialog(
    title: 'Delete Request',
    message: 'Delete request from ${request.name}? This cannot be undone.',
    confirmLabel: 'Delete',
    isDestructive: true,
  );
  if (confirm != true) return;

  try {
    // NOTE: Wala nang FirebaseStorage delete kasi naka-Base64 na ang files
    // Diretso delete na lang sa Firestore
    await FirebaseFirestore.instance.collection('letter_requests').doc(request.id).delete();
    await activity_log.ActivityLogger.log(
      action: 'delete_letter_request',
      module: 'letter_request',
      details: {'orgId': widget.orgId, 'requestId': request.id, 'name': request.name},
    );
    _showSnack('Request deleted successfully');
  } catch (e) {
    _showSnack('Error: $e', isError: true);
  }
}

  Future<void> _markAsReplied(LetterRequestModel request) async {
    final confirm = await _showConfirmDialog(
      title: 'Mark as Replied',
      message: 'Mark this request from ${request.name} as replied?',
      confirmLabel: 'Confirm',
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('letter_requests').doc(request.id).update({
        'status': 'replied',
        'repliedAt': FieldValue.serverTimestamp(),
      });
      await activity_log.ActivityLogger.log(
        action: 'reply_letter_request',
        module: 'letter_request',
        details: {'orgId': widget.orgId, 'requestId': request.id},
      );
      _showSnack('Marked as replied');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

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

  void _exportCSV(List<LetterRequestModel> filtered) {
    try {
      final rows = <List<String>>[
        ['Letter ID', 'Name', 'Email', 'Letter Type', 'Subject', 'Date Submitted', 'Status', 'Replied'],
        ...filtered.map((r) => [
          r.letterId,
          r.name,
          r.email,
          r.letterType,
          r.subject,
          DateFormat('yyyy-MM-dd').format(r.timestamp.toDate()),
          r.status,
          r.replied ? 'Yes' : 'No',
        ]),
      ];
      final csv = rows.map((row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(',')).join('\n');
      // On web, you'd trigger a download; on mobile, share or save.
      // For now we log and show success — integrate with universal_html or share_plus as needed.
      debugPrint(csv);
      _showSnack('Exported ${filtered.length} records to CSV');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro(color: Colors.white)),
      backgroundColor: isError ? OrgColors.error : OrgColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
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
                  isDestructive ? Icons.delete_outline : Icons.check_circle_outline,
                  color: isDestructive ? OrgColors.error : OrgColors.primaryDark,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: OrgColors.primaryLight),
                      ),
                      child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontWeight: FontWeight.w600)),
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
                        elevation: 0,
                      ),
                      child: Text(confirmLabel, style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Build ----
  @override
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
        OutlinedButton.icon(
          onPressed: () => _exportCSV(filtered),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: Text('Export CSV', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: OrgColors.darkGray,
            side: const BorderSide(color: OrgColors.primaryLight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs
          _buildTabs(all),
          // Toolbar
          _buildToolbar(),
          const Divider(height: 0, thickness: 0.5),
          // Table
          Expanded(child: _buildTable(filtered, snapshot)),
        ],
      ),
    );
  }

  Widget _buildTabs(List<LetterRequestModel> all) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OrgColors.primaryLight, width: 0.5)),
      ),
      child: Row(
        children: LetterStatus.values.map((tab) {
          final isActive = _activeTab == tab;
          final count = _tabCount(all, tab);
          return InkWell(
            onTap: () => setState(() { _activeTab = tab; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(
                  color: isActive ? OrgColors.primaryDark : Colors.transparent,
                  width: 2,
                )),
              ),
              child: Row(children: [
                Text(tab.label,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? OrgColors.primaryDark : OrgColors.darkGray,
                    )),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive ? OrgColors.accentBg : OrgColors.lightGray,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$count',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? OrgColors.accentText : OrgColors.darkGray,
                      )),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        // Search
        SizedBox(
          width: 280,
          height: 38,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.beVietnamPro(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search name, subject, ID...',
              hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
              prefixIcon: const Icon(Icons.search, size: 18, color: OrgColors.darkGray),
              filled: true,
              fillColor: OrgColors.lightGray,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; }),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Type filter
        _DropdownFilter(
          value: _typeFilter.isEmpty ? null : _typeFilter,
          hint: 'All Types',
          items: _letterTypes,
          onChanged: (v) => setState(() => _typeFilter = v ?? ''),
        ),
        const SizedBox(width: 10),
        // Sort
        _DropdownFilter(
          value: _sortBy,
          hint: 'Sort',
          items: const ['newest', 'oldest', 'name'],
          labels: const {'newest': 'Newest First', 'oldest': 'Oldest First', 'name': 'Name A–Z'},
          onChanged: (v) => setState(() => _sortBy = v ?? 'newest'),
        ),
        const Spacer(),
        Text(
          'Showing ${_searchQuery.isNotEmpty || _typeFilter.isNotEmpty || _activeTab != LetterStatus.all ? 'filtered results' : 'all requests'}',
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
        ),
      ]),
    );
  }

  Widget _buildTable(List<LetterRequestModel> filtered, AsyncSnapshot<QuerySnapshot> snapshot) {
  // 🔴 CHANGED: Better loading state
  if (snapshot.connectionState == ConnectionState.waiting) {
    return const Center(child: CircularProgressIndicator());
  }
  
  // 🔴 CHANGED: Check for snapshot errors
  if (snapshot.hasError) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: OrgColors.error),
          const SizedBox(height: 12),
          Text(
            'Error: ${snapshot.error}',
            style: GoogleFonts.beVietnamPro(color: OrgColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  if (filtered.isEmpty) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.mail_outline, size: 48, color: OrgColors.mediumGray),
        const SizedBox(height: 12),
        Text(
          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty 
              ? 'No matching requests' 
              : 'No letter requests yet',
          style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
              ? 'Try adjusting your search or filters'
              : 'Click "New Request" to create one',
          style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 12),
        ),
      ]),
    );
  }

  final columns = ['No.', 'Letter ID', 'Name', 'Subject / Type', 'Date Submitted', 'Status', 'Replied', 'Actions'];

  return SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 42,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 68,
        headingRowColor: WidgetStateProperty.all(OrgColors.lightGray),
        dividerThickness: 0.5,
        border: const TableBorder(
          horizontalInside: BorderSide(color: OrgColors.primaryLight, width: 0.5),
        ),
        columns: columns.map((c) => DataColumn(
          label: Text(c,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: OrgColors.darkGray,
              letterSpacing: 0.5,
            ),
          ),
        )).toList(),
        rows: List.generate(filtered.length, (i) {
          final req = filtered[i];
          final isReplied = req.replied || req.status == 'replied';
          
          // 🔴 ADDED: Skip if request has error
          if (req.letterId == 'ERROR') {
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text('ERROR', style: GoogleFonts.beVietnamPro(color: Colors.red))),
              DataCell(Text('Failed to load', style: GoogleFonts.beVietnamPro(color: Colors.red))),
              DataCell(Container()),
              DataCell(Container()),
              DataCell(Container()),
              DataCell(Container()),
              DataCell(Container()),
            ]);
          }
          
          return DataRow(cells: [
            DataCell(Text('${i + 1}',
                style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 13))),
            DataCell(Text(req.letterId,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: OrgColors.darkGray,
                ))),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(req.name,
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(req.email,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
              ],
            )),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(req.letterType,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.primaryDark)),
                Text(req.subject,
                    style: GoogleFonts.beVietnamPro(fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
            DataCell(Text(
              DateFormat('MMM dd, yyyy').format(req.timestamp.toDate()),
              style: GoogleFonts.beVietnamPro(fontSize: 12),
            )),
            DataCell(_buildStatusBadge(req.status)), 
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isReplied ? OrgColors.successBg : OrgColors.warningBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isReplied ? 'YES' : 'NO',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isReplied ? OrgColors.success : OrgColors.warning,
                  ),
                ),
              ),
            ),
            DataCell(Row(children: [
              if (!isReplied)
                _ActionIconButton(
                  icon: Icons.mark_email_read_outlined,
                  tooltip: 'Mark as Replied',
                  color: OrgColors.success,
                  onTap: () => _markAsReplied(req),
                ),
              _ActionIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                color: OrgColors.info,
                onTap: () => _openEditRequestModal(req),
              ),
              _ActionIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                color: OrgColors.error,
                onTap: () => _deleteRequest(req),
              ),
            ])),
          ]);
        }),
      ),
    ),
  );
}

// Simple status badge - DISPLAY ONLY, no interaction
Widget _buildStatusBadge(String status) {
  Color bgColor;
  Color textColor;
  String label;
  
  switch (status.toLowerCase()) {
    case 'approved':
      bgColor = OrgColors.successBg;
      textColor = OrgColors.success;
      label = 'Approved';
      break;
    case 'rejected':
      bgColor = OrgColors.errorBg;
      textColor = OrgColors.error;
      label = 'Rejected';
      break;
    case 'replied':
      bgColor = OrgColors.successBg;
      textColor = OrgColors.success;
      label = 'Replied';
      break;
    case 'review':
      bgColor = OrgColors.reviewBg;
      textColor = OrgColors.reviewColor;
      label = 'On Review';
      break;
    default:
      bgColor = OrgColors.warningBg;
      textColor = OrgColors.warning;
      label = 'Pending';
  }
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    ),
  );
}
}

// ============ SMALL WIDGETS ============

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OrgColors.primaryLight, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: GoogleFonts.beVietnamPro(fontSize: 26, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
            Text(label,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
          ]),
        ]),
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final Map<String, String>? labels;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: OrgColors.lightGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OrgColors.primaryLight, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: OrgColors.darkGray),
          items: [
            DropdownMenuItem(value: null, child: Text(hint, style: GoogleFonts.beVietnamPro(fontSize: 13))),
            ...items.map((i) => DropdownMenuItem(
              value: i,
              child: Text(labels?[i] ?? i, style: GoogleFonts.beVietnamPro(fontSize: 13)),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const _StatusChip({required this.status, required this.onChanged});

  static final _map = <String, Map<String, dynamic>>{
    'pending':  {'label': 'Pending',  'bg': OrgColors.warningBg, 'fg': OrgColors.warning},
    'approved': {'label': 'Approved', 'bg': OrgColors.successBg, 'fg': OrgColors.success},
    'rejected': {'label': 'Rejected', 'bg': OrgColors.errorBg,   'fg': OrgColors.error},
    'review':   {'label': 'On Review','bg': OrgColors.reviewBg,  'fg': OrgColors.reviewColor},
    'replied':  {'label': 'Replied',  'bg': OrgColors.successBg, 'fg': OrgColors.success},
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _map[status] ?? _map['pending']!;
    return PopupMenuButton<String>(
      tooltip: 'Change status',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      offset: const Offset(0, 32),
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cfg['bg'] as Color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(cfg['label'] as String,
              style: GoogleFonts.beVietnamPro(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: cfg['fg'] as Color,
              )),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 14, color: cfg['fg'] as Color),
        ]),
      ),
      itemBuilder: (_) => ['pending', 'approved', 'rejected', 'review', 'replied']
          .where((s) => s != status)
          .map((s) {
            final c = _map[s]!;
            return PopupMenuItem(
              value: s,
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: c['fg'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(c['label'] as String,
                    style: GoogleFonts.beVietnamPro(fontSize: 13)),
              ]),
            );
          }).toList(),
    );
  }
}

// ============ LETTER REQUEST MODAL ============
class _LetterRequestModal extends StatefulWidget {
  final String orgId;
  final LetterRequestModel? existingRequest;

  const _LetterRequestModal({required this.orgId, this.existingRequest});

  @override
  State<_LetterRequestModal> createState() => _LetterRequestModalState();
}

class _LetterRequestModalState extends State<_LetterRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _letterType = 'Recruitment Letter';
  
  // ⭐ CHANGED: Use Base64 like Event Proposal
  String? _attachmentBase64;
  String? _attachmentName;
  String? _attachmentSize;
  
  bool _isSubmitting = false;
  bool _isUploading  = false;
  double _uploadProgress = 0.0;

  static const List<String> _letterTypes = [
    'Recruitment Letter',
    'Appreciation Letter',
    'Permission Letter',
    'Request Letter for Venue',
    'Sponsorship Letter',
    'General Inquiry',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.existingRequest;
    if (r != null) {
      _nameCtrl.text    = r.name;
      _emailCtrl.text   = r.email;
      _subjectCtrl.text = r.subject;
      _messageCtrl.text = r.message;
      _letterType       = r.letterType;
      _attachmentBase64 = r.attachmentBase64;
      _attachmentName   = r.attachmentName;
      _attachmentSize   = r.attachmentSize;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ⭐ NEW: File picker with Base64 (copied from Event Proposal)
  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png'],
      withData: true,  // Important: gets file bytes
    );
    
    if (result == null) return;
    final file = result.files.first;

    if (file.bytes == null || file.bytes!.isEmpty) {
      _showMessage('Cannot read file!', isError: true);
      return;
    }

    final fileSizeBytes = file.bytes!.length;
    final maxSize = 700 * 1024; // 700KB max
    
    if (fileSizeBytes > maxSize) {
      final sizeInKB = (fileSizeBytes / 1024).toStringAsFixed(1);
      _showMessage('File is $sizeInKB KB. Maximum is 700 KB!', isError: true);
      return;
    }

    final fileSizeKB = (fileSizeBytes / 1024).toStringAsFixed(1);
    
    // Show uploading progress
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _attachmentName = file.name;
      _attachmentSize = '$fileSizeKB KB';
    });

    // Simulate progress for better UX
    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(Duration(milliseconds: 50));
      if (mounted) {
        setState(() => _uploadProgress = i / 100);
      }
    }

    try {
      // ⭐ KEY: Convert to Base64 (same as Event Proposal)
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check attachment for new requests
    if (widget.existingRequest == null && _attachmentBase64 == null) {
      _showMessage('Please attach a file before submitting!', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> data = {
        'orgId':       widget.orgId,
        'name':        _nameCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'letterType':  _letterType,
        'subject':     _subjectCtrl.text.trim(),
        'message':     _messageCtrl.text.trim(),
        // ⭐ NEW: Store attachment as Base64
        'attachmentBase64': _attachmentBase64,
        'attachmentName':   _attachmentName,
        'attachmentSize':   _attachmentSize,
        'updatedAt':   FieldValue.serverTimestamp(),
      };

      final col = FirebaseFirestore.instance.collection('letter_requests');
      
      if (widget.existingRequest != null) {
        // Edit existing
        await col.doc(widget.existingRequest!.id).update(data);
        await activity_log.ActivityLogger.log(
          action: 'edit_letter_request',
          module: 'letter_request',
          details: {'orgId': widget.orgId, 'requestId': widget.existingRequest!.id},
        );
        _showMessage('Letter request updated successfully!');
      } else {
        // New request
        final letterId = 'RLR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        data['status']    = 'pending';
        data['replied']   = false;
        data['letterId']  = letterId;
        data['timestamp'] = FieldValue.serverTimestamp();
        await col.add(data);
        await activity_log.ActivityLogger.log(
          action: 'create_letter_request',
          module: 'letter_request',
          details: {'orgId': widget.orgId, 'name': data['name']},
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

  // ⭐ NEW: File attachment UI (copied from Event Proposal)
  Widget _buildFileAttachment() {
    final hasFile = _attachmentBase64 != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Attachment ${widget.existingRequest == null ? '*' : ''}',
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: OrgColors.charcoal,
          ),
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
                  : hasFile
                      ? OrgColors.success
                      : OrgColors.mediumGray,
              width: _isUploading || hasFile ? 1.5 : 1,
            ),
          ),
          child: _isUploading
              ? _buildUploadingState()
              : hasFile
                  ? _buildUploadedState()
                  : _buildIdleState(),
        ),
      ],
    );
  }

  Widget _buildIdleState() {
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
                const TextSpan(text: 'letter documents'),
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

  Widget _buildUploadingState() {
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
              _attachmentName ?? 'Uploading...',
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
            _attachmentSize ?? '',
            style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray),
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
        Text(
          'Uploading ${(_uploadProgress * 100).clamp(0, 100).toInt()}%',
          style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray),
        ),
      ],
    );
  }

  Widget _buildUploadedState() {
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
            _attachmentName ?? 'File attached',
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: OrgColors.charcoal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (_attachmentSize != null)
            Text(
              _attachmentSize!,
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
        child: Text('Remove', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.error)),
      ),
      TextButton(
        onPressed: _pickAndUploadFile,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text('Change', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.primaryDark)),
      ),
    ]);
  }

  // Helper widgets (keep your existing ones)
  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 0.5, color: OrgColors.darkGray),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.mediumGray),
      filled: true,
      fillColor: OrgColors.lightGray,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: OrgColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: OrgColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: OrgColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingRequest != null;
    final hasFile = _attachmentBase64 != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 540,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          decoration: _inputDecoration('FULL NAME *', hint: 'e.g. Jonathan Doe'),
                          validator: (v) => v?.trim().isEmpty == true ? 'Full name is required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          decoration: _inputDecoration('EMAIL ADDRESS *', hint: 'john@example.com'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v?.trim().isEmpty == true) return 'Email is required';
                            if (!v!.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _letterType,
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
                          decoration: _inputDecoration('LETTER TYPE *'),
                          items: _letterTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _letterType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _subjectCtrl,
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          decoration: _inputDecoration('SUBJECT *', hint: "What's this regarding?"),
                          validator: (v) => v?.trim().isEmpty == true ? 'Subject is required' : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _messageCtrl,
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      decoration: _inputDecoration('MESSAGE / COMMENT *', hint: 'Provide details about your request...'),
                      maxLines: 4,
                      validator: (v) => v?.trim().isEmpty == true ? 'Message is required' : null,
                    ),
                    const SizedBox(height: 14),
                    // ⭐ NEW: File attachment widget
                    _buildFileAttachment(),
                  ]),
                ),
              ),

              // Footer
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
                        side: const BorderSide(color: OrgColors.primaryLight),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting || _isUploading ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 16, color: Colors.white),
                      label: Text(
                        isEdit ? 'Save Changes' : 'Submit Request',
                        style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrgColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        disabledBackgroundColor: OrgColors.primaryDark.withOpacity(0.5),
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
}

// ============ LETTER REQUEST MODEL ============
class LetterRequestModel {
  final String id;
  final String letterId;
  final String name;
  final String email;
  final String letterType;
  final String subject;
  final String message;
  // ⭐ NEW: Base64 attachment fields
  final String? attachmentBase64;
  final String? attachmentName;
  final String? attachmentSize;
  final String status;
  final bool replied;
  final Timestamp timestamp;
  final Timestamp? repliedAt;

  LetterRequestModel({
    required this.id,
    required this.letterId,
    required this.name,
    required this.email,
    required this.letterType,
    required this.subject,
    required this.message,
    this.attachmentBase64,
    this.attachmentName,
    this.attachmentSize,
    required this.status,
    required this.replied,
    required this.timestamp,
    this.repliedAt,
  });

  factory LetterRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LetterRequestModel(
      id:            doc.id,
      letterId:      d['letterId'] ?? 'RLR-${doc.id.substring(0, 6).toUpperCase()}',
      name:          d['name'] ?? '',
      email:         d['email'] ?? '',
      letterType:    d['letterType'] ?? '',
      subject:       d['subject'] ?? '',
      message:       d['message'] ?? '',
      attachmentBase64: d['attachmentBase64'],
      attachmentName:   d['attachmentName'],
      attachmentSize:   d['attachmentSize'],
      status:        d['status'] ?? 'pending',
      replied:       d['replied'] ?? (d['status'] == 'replied'),
      timestamp:     d['timestamp'] as Timestamp? ?? Timestamp.now(),
      repliedAt:     d['repliedAt'] as Timestamp?,
    );
  }
}


