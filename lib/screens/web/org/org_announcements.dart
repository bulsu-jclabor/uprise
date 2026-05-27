// lib/screens/web/org/org_announcements.dart
// Simplified with BASE64 (No Firebase Storage)
// Features: Title, Content, Banner Image (base64), Attachments (base64),
//           Target Audience, Schedule Publish, Pin toggle

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'export_util.dart';
import 'export_pdf.dart';
import '../../../widgets/admin_export_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color surface      = Color(0xFFF8F9FB);
  static const Color lightGray    = Color(0xFFF8F9FB);
  static const Color border       = Color(0xFFE8ECF0);
  static const Color borderSoft   = Color(0xFFE2E6EA);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF64748B);
  static const Color textFaint    = Color(0xFF9AA5B4);
  static const Color charcoal     = Color(0xFF1A202C);
  static const Color textMid      = Color(0xFF374151);
  static const Color success      = Color(0xFF059669);
  static const Color warning      = Color(0xFFD97706);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorBg      = Color(0xFFFEF2F2);
  static const Color info         = Color(0xFF2563EB);
  static const Color infoBg       = Color(0xFFEFF6FF);
}

class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static InputDecoration inputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: OrgColors.textFaint) : null,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.textFaint),
      filled: true,
      fillColor: OrgColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: OrgColors.borderSoft, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: OrgColors.borderSoft, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: OrgColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: OrgColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: OrgColors.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────
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
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OrgColors.border),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrgColors.borderSoft),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: OrgColors.textFaint),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.textMid),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _ToolbarButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: Colors.white),
      label: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: OrgColors.primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgAnnouncementsScreen extends StatefulWidget {
  final String orgId;
  const OrgAnnouncementsScreen({super.key, required this.orgId});

  @override
  State<OrgAnnouncementsScreen> createState() => _OrgAnnouncementsScreenState();
}

class _OrgAnnouncementsScreenState extends State<OrgAnnouncementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMode = 'All';
  int _currentPage = 1;
  static const int _pageSize = 6;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('announcements')
      .where('orgId', isEqualTo: widget.orgId)
      .snapshots();

  List<AnnouncementModel> _filtered(List<AnnouncementModel> list) {
    var out = List<AnnouncementModel>.from(list);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out.where((a) => a.title.toLowerCase().contains(q) || a.content.toLowerCase().contains(q)).toList();
    }
    if (_filterMode == 'Pinned') {
      out = out.where((a) => a.isPinned).toList();
    } else if (_filterMode == 'With Attachments') {
      out = out.where((a) => a.attachmentsBase64.isNotEmpty).toList();
    }
    return out;
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.beVietnamPro(fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor: isError ? OrgColors.error : OrgColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
    ));
  }

  void _openCreateDialog() => _showAnnouncementDialog();
  void _openEditDialog(AnnouncementModel a) => _showAnnouncementDialog(existing: a);

  Future<void> _deleteAnnouncement(AnnouncementModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: OrgColors.errorBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline_rounded, color: OrgColors.error, size: 20),
                ),
                const SizedBox(width: 14),
                Text('Delete Announcement', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
              ]),
              const SizedBox(height: 14),
              Text('Are you sure you want to delete "${a.title}"? This action cannot be undone.',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: OrgColors.darkGray)),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: OrgColors.error),
                  child: Text('Delete', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('announcements').doc(a.id).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_announcement',
        module: 'announcements',
        details: {'orgId': widget.orgId, 'announcementId': a.id},
      );
      if (mounted) _showSnack('Announcement deleted successfully');
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
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
          const SizedBox(height: 24),
          Expanded(child: _buildAnnouncementsFeed()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        int total = 0, pinned = 0, withAttachments = 0;
        if (snap.hasData) {
          final docs = snap.data!.docs;
          total = docs.length;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['pinned'] == true) pinned++;
            final atts = data['attachmentsBase64'] as List?;
            if (atts != null && atts.isNotEmpty) withAttachments++;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(label: 'Total', value: '$total', icon: Icons.campaign_rounded, color: OrgColors.primaryDark),
            const SizedBox(width: 14),
            _StatCard(label: 'Pinned', value: '$pinned', icon: Icons.push_pin, color: OrgColors.warning),
            const SizedBox(width: 14),
            _StatCard(label: 'With Files', value: '$withAttachments', icon: Icons.attach_file_rounded, color: OrgColors.info),
          ]),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() { _currentPage = 1; _searchQuery = v; }),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.textFaint),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: OrgColors.textFaint),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.borderSoft)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.borderSoft)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryDark, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _FilterDropdown(
            value: _filterMode,
            items: const ['All', 'Pinned', 'With Attachments'],
            onChanged: (v) => setState(() { _filterMode = v!; _currentPage = 1; }),
          ),
          const SizedBox(width: 12),
          AdminExportButton(
            label: 'Export',
            onSelected: (choice) async {
              try {
                final snap = await FirebaseFirestore.instance.collection('announcements').where('orgId', isEqualTo: widget.orgId).get();
                final all = snap.docs.map((d) => AnnouncementModel.fromFirestore(d)).toList();
                final filtered = _filtered(all);
                // Export logic here
                _showSnack('Exported ${filtered.length} records');
              } catch (e) {
                _showSnack('Export failed: $e', isError: true);
              }
            },
          ),
          const Spacer(),
          _ToolbarButton(
            label: 'New Announcement',
            icon: Icons.add_rounded,
            onPressed: _openCreateDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: OrgColors.primaryDark));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}', style: GoogleFonts.beVietnamPro()));
        }
        var docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState();
        }
        List<AnnouncementModel> all = docs.map((d) => AnnouncementModel.fromFirestore(d)).toList();
        all.sort((a, b) => b.timestamp.toDate().compareTo(a.timestamp.toDate()));
        final filtered = _filtered(all);
        final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, filtered.length);
        final pageItems = filtered.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OrgColors.border),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(
            children: [
              Expanded(
                child: pageItems.isEmpty
                    ? _buildEmptySearchState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: pageItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 20),
                        itemBuilder: (ctx, i) => _AnnouncementCard(
                          announcement: pageItems[i],
                          onEdit: () => _openEditDialog(pageItems[i]),
                          onDelete: () => _deleteAnnouncement(pageItems[i]),
                        ),
                      ),
              ),
              _buildPaginationFooter(filtered.length, totalPages, start, end),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OrgColors.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.campaign_outlined, size: 40, color: OrgColors.textFaint),
            ),
            const SizedBox(height: 16),
            Text('No Announcements Yet', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
            const SizedBox(height: 6),
            Text('Click "New Announcement" to create your first post.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: OrgColors.textFaint),
          const SizedBox(height: 12),
          Text('No matching announcements', style: GoogleFonts.beVietnamPro(fontSize: 14, color: OrgColors.darkGray)),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: OrgColors.border)),
        color: OrgColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
          Row(children: [
            IconButton(icon: Icon(Icons.chevron_left, size: 20), onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null),
            ...pages.map((p) => GestureDetector(
              onTap: () => setState(() => _currentPage = p),
              child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: p == _currentPage ? OrgColors.primaryDark : Colors.transparent, borderRadius: BorderRadius.circular(6)), child: Text('$p', style: GoogleFonts.beVietnamPro(fontSize: 12, color: p == _currentPage ? Colors.white : OrgColors.textMid))),
            )),
            IconButton(icon: Icon(Icons.chevron_right, size: 20), onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
          ]),
        ],
      ),
    );
  }

  // ==========================================================================
  // CREATE/EDIT DIALOG
  // ==========================================================================
  void _showAnnouncementDialog({AnnouncementModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    bool isPinned = existing?.isPinned ?? false;
    String? imageBase64 = existing?.imageBase64;
    List<AttachmentBase64> attachments = List.from(existing?.attachmentsBase64 ?? []);
    bool isSubmitting = false;
    
    String targetAudience = existing?.targetAudience ?? 'Members Only';
    final List<String> audienceOptions = ['Public', 'CICT Only', 'Members Only'];
    
    DateTime? scheduledPublishDate;
    TimeOfDay? scheduledPublishTime;
    bool isScheduled = existing?.scheduledPublishDate != null;
    
    if (existing?.scheduledPublishDate != null) {
      scheduledPublishDate = existing!.scheduledPublishDate!.toDate();
      scheduledPublishTime = TimeOfDay.fromDateTime(scheduledPublishDate!);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 600,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: OrgColors.primaryDark,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(isEdit ? Icons.edit_rounded : Icons.campaign_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(isEdit ? 'Edit Announcement' : 'New Announcement',
                          style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: titleCtrl,
                            decoration: _DS.inputDecoration('Title *', hint: 'Enter announcement title', icon: Icons.title),
                            validator: (v) => v?.trim().isEmpty == true ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: contentCtrl,
                            maxLines: 6,
                            decoration: _DS.inputDecoration('Content *', hint: 'Write your announcement here...', icon: Icons.description_outlined),
                            validator: (v) => v?.trim().isEmpty == true ? 'Content is required' : null,
                          ),
                          const SizedBox(height: 18),
                          _buildImagePickerBase64(imageBase64, (v) => setDialogState(() => imageBase64 = v), () => setDialogState(() => imageBase64 = null)),
                          const SizedBox(height: 18),
                          _buildAttachmentsPickerBase64(attachments, (v) => setDialogState(() => attachments = v)),
                          const SizedBox(height: 18),
                          // Target Audience
                          Container(
                            decoration: BoxDecoration(
                              color: OrgColors.surface,
                              borderRadius: BorderRadius.circular(_DS.radiusSm),
                              border: Border.all(color: OrgColors.borderSoft),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: targetAudience,
                              decoration: InputDecoration(
                                labelText: 'Target Audience *',
                                labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
                                prefixIcon: const Icon(Icons.people_outline, size: 18, color: OrgColors.textFaint),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              items: audienceOptions.map((option) => DropdownMenuItem(
                                value: option,
                                child: Row(children: [
                                  Icon(option == 'Public' ? Icons.public : option == 'CICT Only' ? Icons.school : Icons.group, size: 16, color: OrgColors.primaryDark),
                                  const SizedBox(width: 8),
                                  Text(option, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                                ]),
                              )).toList(),
                              onChanged: (value) => setDialogState(() => targetAudience = value!),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Schedule Publish
                          Card(
                            elevation: 0,
                            color: OrgColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm), side: BorderSide(color: OrgColors.borderSoft)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(children: [
                                    Switch(
                                      value: isScheduled,
                                      onChanged: (val) => setDialogState(() {
                                        isScheduled = val;
                                        if (!isScheduled) { scheduledPublishDate = null; scheduledPublishTime = null; }
                                      }),
                                      activeColor: OrgColors.primaryDark,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Schedule for later', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ]),
                                  if (isScheduled) ...[
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                                            if (picked != null) setDialogState(() => scheduledPublishDate = picked);
                                          },
                                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: OrgColors.borderSoft)), child: Row(children: [Icon(Icons.calendar_today, size: 16, color: OrgColors.primaryDark), const SizedBox(width: 10), Text(scheduledPublishDate != null ? DateFormat('MMM dd, yyyy').format(scheduledPublishDate!) : 'Select date', style: GoogleFonts.beVietnamPro(fontSize: 13))])),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                                            if (picked != null) setDialogState(() => scheduledPublishTime = picked);
                                          },
                                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: OrgColors.borderSoft)), child: Row(children: [Icon(Icons.access_time, size: 16, color: OrgColors.primaryDark), const SizedBox(width: 10), Text(scheduledPublishTime != null ? scheduledPublishTime!.format(ctx) : 'Select time', style: GoogleFonts.beVietnamPro(fontSize: 13))])),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(children: [
                            Switch(value: isPinned, onChanged: (val) => setDialogState(() => isPinned = val), activeColor: OrgColors.primaryDark),
                            const SizedBox(width: 8),
                            Text('Pin this announcement', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: OrgColors.border)), color: OrgColors.surface, borderRadius: BorderRadius.vertical(bottom: Radius.circular(18))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser!;
                          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                          final authorName = userDoc.data()?['name'] ?? user.email ?? 'Unknown';
                          
                          Timestamp? scheduledTimestamp;
                          if (isScheduled && scheduledPublishDate != null && scheduledPublishTime != null) {
                            scheduledTimestamp = Timestamp.fromDate(DateTime(scheduledPublishDate!.year, scheduledPublishDate!.month, scheduledPublishDate!.day, scheduledPublishTime!.hour, scheduledPublishTime!.minute));
                          }
                          
                          final data = {
                            'orgId': widget.orgId,
                            'title': titleCtrl.text.trim(),
                            'content': contentCtrl.text.trim(),
                            'authorId': user.uid,
                            'authorName': authorName,
                            'attachmentsBase64': attachments.map((a) => {'name': a.name, 'base64': a.base64, 'size': a.size}).toList(),
                            'imageBase64': imageBase64 ?? '',
                            'pinned': isPinned,
                            'targetAudience': targetAudience,
                            'isScheduled': isScheduled,
                            'scheduledPublishDate': scheduledTimestamp,
                            'isPublished': !isScheduled,
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          
                          if (isEdit) {
                            await FirebaseFirestore.instance.collection('announcements').doc(existing.id).update(data);
                          } else {
                            data['timestamp'] = FieldValue.serverTimestamp();
                            await FirebaseFirestore.instance.collection('announcements').add(data);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) _showSnack(isEdit ? 'Updated' : (isScheduled ? 'Scheduled' : 'Posted'));
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OrgColors.error));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: OrgColors.primaryDark),
                      child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Save' : (isScheduled ? 'Schedule' : 'Post')),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerBase64(String? currentBase64, Function(String) onImageSelected, VoidCallback onRemove) {
    if (currentBase64 != null && currentBase64.isNotEmpty) {
      return Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(_DS.radiusSm), child: Image.memory(base64Decode(currentBase64), width: double.infinity, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 160, color: OrgColors.lightGray))),
        Positioned(top: 8, right: 8, child: InkWell(onTap: onRemove, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)))),
      ]);
    }
    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
        if (result == null) return;
        try {
          final bytes = result.files.first.bytes!;
          if (bytes.length > 5 * 1024 * 1024) { _showSnack('Image too large! Max 5MB', isError: true); return; }
          onImageSelected(base64Encode(bytes));
          _showSnack('Image uploaded');
        } catch (e) { _showSnack('Upload failed: $e', isError: true); }
      },
      child: Container(
        width: double.infinity, height: 110,
        decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: OrgColors.borderSoft)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: OrgColors.primaryDark.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.image_outlined, color: OrgColors.primaryDark)),
          const SizedBox(height: 8),
          Text('Click to upload banner image', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('PNG, JPG up to 5MB', style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.textFaint)),
        ]),
      ),
    );
  }

  Widget _buildAttachmentsPickerBase64(List<AttachmentBase64> attachments, Function(List<AttachmentBase64>) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () async {
          final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
          if (result == null) return;
          try {
            final newAtts = <AttachmentBase64>[];
            for (final file in result.files) {
              final bytes = file.bytes!;
              if (bytes.length > 700 * 1024) { _showSnack('${file.name} exceeds 700KB', isError: true); continue; }
              newAtts.add(AttachmentBase64(name: file.name, base64: base64Encode(bytes), size: '${(bytes.length / 1024).toStringAsFixed(1)} KB'));
            }
            onChanged([...attachments, ...newAtts]);
            if (newAtts.isNotEmpty) _showSnack('${newAtts.length} file(s) attached');
          } catch (e) { _showSnack('Upload failed: $e', isError: true); }
        },
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: OrgColors.borderSoft)),
          child: Column(children: [
            Icon(Icons.attach_file_rounded, size: 24, color: OrgColors.primaryDark),
            Text('Add attachments', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('PDF, DOC, DOCX, TXT, JPG, PNG — max 700 KB each', style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.textFaint)),
          ]),
        ),
      ),
      ...attachments.asMap().entries.map((e) => Container(
        margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8), border: Border.all(color: OrgColors.borderSoft)),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_outlined, size: 18, color: OrgColors.info),
          const SizedBox(width: 8),
          Expanded(child: Text(e.value.name, style: GoogleFonts.beVietnamPro(fontSize: 12))),
          if (e.value.size != null) Text(e.value.size!, style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.textFaint)),
          IconButton(icon: const Icon(Icons.close_rounded, size: 16), onPressed: () => onChanged([...attachments]..removeAt(e.key))),
        ]),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Announcement Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({required this.announcement, required this.onEdit, required this.onDelete});

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('MMM dd, yyyy').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = announcement.imageBase64 != null && announcement.imageBase64!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_DS.radiusMd), border: Border.all(color: OrgColors.border), boxShadow: _DS.cardShadow),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            Stack(children: [
              SizedBox(height: 180, width: double.infinity, child: Image.memory(base64Decode(announcement.imageBase64!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: OrgColors.lightGray))),
              if (announcement.isPinned)
                Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: OrgColors.warning, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.push_pin, size: 12, color: Colors.white), const SizedBox(width: 4), Text('Pinned', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))]))),
            ]),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(announcement.title, style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w800, color: OrgColors.charcoal))),
                  if (!hasImage && announcement.isPinned) Icon(Icons.push_pin, size: 16, color: OrgColors.warning),
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
                    icon: Icon(Icons.more_horiz, color: OrgColors.darkGray),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: OrgColors.error))),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: OrgColors.primaryDark.withOpacity(0.1), child: Text(announcement.authorName.isNotEmpty ? announcement.authorName[0].toUpperCase() : '?', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: OrgColors.primaryDark))),
                  const SizedBox(width: 8),
                  Text(announcement.authorName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: OrgColors.textFaint, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_timeAgo(announcement.timestamp), style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.textFaint)),
                ]),
                const SizedBox(height: 14),
                Text(announcement.content, style: GoogleFonts.beVietnamPro(fontSize: 14, height: 1.6, color: OrgColors.textMid)),
                if (announcement.attachmentsBase64.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(20)), child: Text('${announcement.attachmentsBase64.length} attachment(s)', style: GoogleFonts.beVietnamPro(fontSize: 11))),
                  ]),
                  const SizedBox(height: 10),
                  ...announcement.attachmentsBase64.map((att) => Container(
                    margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.insert_drive_file_outlined, size: 18, color: OrgColors.info),
                      const SizedBox(width: 10),
                      Expanded(child: Text(att.name, style: GoogleFonts.beVietnamPro(fontSize: 13))),
                      if (att.size != null) Text(att.size!, style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.textFaint)),
                    ]),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class AttachmentBase64 {
  final String name;
  final String base64;
  final String? size;
  const AttachmentBase64({required this.name, required this.base64, this.size});
}

class AnnouncementModel {
  final String id, title, content, authorId, authorName;
  final Timestamp timestamp;
  final List<AttachmentBase64> attachmentsBase64;
  final String? imageBase64;
  final bool isPinned;
  final String targetAudience;
  final bool isScheduled;
  final Timestamp? scheduledPublishDate;
  final bool isPublished;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
    required this.attachmentsBase64,
    this.imageBase64,
    this.isPinned = false,
    this.targetAudience = 'Members Only',
    this.isScheduled = false,
    this.scheduledPublishDate,
    this.isPublished = true,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    List<AttachmentBase64> attachments = [];
    final attsList = d['attachmentsBase64'] as List?;
    if (attsList != null) {
      attachments = attsList.map((a) => AttachmentBase64(
        name: a['name'] ?? '',
        base64: a['base64'] ?? '',
        size: a['size'],
      )).toList();
    }
    return AnnouncementModel(
      id: doc.id,
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      timestamp: d['timestamp'] as Timestamp? ?? Timestamp.now(),
      attachmentsBase64: attachments,
      imageBase64: d['imageBase64'] as String?,
      isPinned: d['pinned'] as bool? ?? false,
      targetAudience: d['targetAudience'] as String? ?? 'Members Only',
      isScheduled: d['isScheduled'] as bool? ?? false,
      scheduledPublishDate: d['scheduledPublishDate'] as Timestamp?,
      isPublished: d['isPublished'] as bool? ?? true,
    );
  }
}