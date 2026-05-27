// lib/screens/web/org/org_announcements.dart
// Redesigned to match StudentAccounts professional layout:
// - Stats cards, search/filter toolbar, export CSV, pagination
// - Modal dialogs for create/edit (instead of side sheet)
// - Image uploads go to Firebase Storage (no base64 in Firestore)
// - Attachments stored in Firebase Storage
// - Clean card-based announcement feed inside a container

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../../widgets/admin_export_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens (consistent with student accounts)
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

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
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
// Reusable small widgets (mirror student accounts)
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
                color: Color.fromRGBO((color.r * 255).round(), (color.g * 255).round(), (color.b * 255).round(), 0.10),
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
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
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
  final String hint;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

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
  final bool outlined;
  // ignore: unused_element_parameter
  const _ToolbarButton({required this.label, required this.icon, required this.onPressed, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: OrgColors.primaryDark,
          side: BorderSide(color: OrgColors.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: Colors.white),
      label: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: OrgColors.primaryDark,
        foregroundColor: Colors.white,
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
  String _filterMode = 'All'; // All, Pinned, With Attachments
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
      out = out.where((a) =>
          a.title.toLowerCase().contains(q) ||
          a.content.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q)).toList();
    }
    if (_filterMode == 'Pinned') {
      out = out.where((a) => a.isPinned).toList();
    } else if (_filterMode == 'With Attachments') {
      out = out.where((a) => a.attachments.isNotEmpty).toList();
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
      margin: const EdgeInsets.all(16),
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
              Text(
                'Are you sure you want to delete "${a.title}"? This action cannot be undone.',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: OrgColors.darkGray, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: OrgColors.borderSoft),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.textMid)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrgColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Delete', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;

    try {
      for (final att in a.attachments) {
        try {
          await FirebaseStorage.instance.refFromURL(att.url).delete();
        } catch (_) {}
      }
      if (a.imageUrl != null && a.imageUrl!.isNotEmpty && !a.imageUrl!.startsWith('data:image')) {
        try {
          await FirebaseStorage.instance.refFromURL(a.imageUrl!).delete();
        } catch (_) {}
      }
      await FirebaseFirestore.instance.collection('announcements').doc(a.id).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_announcement',
        module: 'announcements',
        details: {'orgId': widget.orgId, 'announcementId': a.id, 'title': a.title},
      );
      if (mounted) _showSnack('Announcement deleted successfully', isError: false);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
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
            final atts = data['attachments'] as List?;
            if (atts != null && atts.isNotEmpty) withAttachments++;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(label: 'Total Announcements', value: '$total', icon: Icons.campaign_rounded, color: OrgColors.primaryDark),
            const SizedBox(width: 14),
            _StatCard(label: 'Pinned', value: '$pinned', icon: Icons.push_pin, color: OrgColors.warning),
            const SizedBox(width: 14),
            _StatCard(label: 'With Attachments', value: '$withAttachments', icon: Icons.attach_file_rounded, color: OrgColors.info),
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
                hintText: 'Search announcements...',
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
            hint: 'Filter',
            icon: Icons.filter_list,
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
                  if (choice == 'csv') {
                  // Build CSV
                  final lines = [
                    ['ID', 'Title', 'Category', 'Author', 'Timestamp', 'Attachments', 'Content'],
                    ...filtered.map((r) => [
                          r.id,
                          r.title.replaceAll('"', '""'),
                          r.category,
                          r.authorName,
                          r.timestamp.toDate().toIso8601String(),
                          r.attachments.length.toString(),
                          r.content.replaceAll('\n', ' ').replaceAll('"', '""'),
                        ])
                  ];
                  final csv = lines.map((row) => row.map((c) => '"$c"').join(',')).join('\n');
                  await OrgExportUtil.saveText(csv, 'announcements_${DateTime.now().millisecondsSinceEpoch}.csv', mimeType: 'text/csv');
                  _showSnack('Exported ${filtered.length} announcement(s)', isError: false);
                } else if (choice == 'pdf') {
                  final headers = ['ID', 'Title', 'Category', 'Author', 'Timestamp', 'Attachments', 'Content'];
                  final rows = filtered.map((r) => [
                    r.id,
                    r.title,
                    r.category,
                    r.authorName,
                    r.timestamp.toDate().toIso8601String(),
                    r.attachments.length.toString(),
                    r.content.replaceAll('\n', ' '),
                  ]).toList();
                  final pdfBytes = await OrgExportPdf.generateTablePdf(title: 'Announcements', headers: headers, rows: rows);
                  await OrgExportUtil.saveBytes(pdfBytes, 'announcements_${DateTime.now().millisecondsSinceEpoch}.pdf', mimeType: 'application/pdf');
                  _showSnack('Exported ${filtered.length} announcement(s) to PDF', isError: false);
                }
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
          final err = snap.error.toString();
          // Detect Firestore 'requires an index' error and extract the console URL
          final idxMatch = RegExp(r'https?:\/\/console\.firebase\.google\.com[^\s\)]+').firstMatch(err);
          if (idxMatch != null) {
            final idxUrl = idxMatch.group(0)!;
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Firestore query requires an index.', style: GoogleFonts.beVietnamPro(fontSize: 14, color: OrgColors.darkGray)),
                const SizedBox(height: 8),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Create the index in Firebase Console to enable server-side ordering. Or continue without the index (client-side sorting is used).', textAlign: TextAlign.center, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.textFaint))),
                const SizedBox(height: 12),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton(
                    onPressed: () async {
                      Clipboard.setData(ClipboardData(text: idxUrl));
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Index URL copied to clipboard'), backgroundColor: OrgColors.success));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: OrgColors.primaryDark),
                    child: Text('Copy Index URL', style: GoogleFonts.beVietnamPro(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await launchUrlString(idxUrl, mode: LaunchMode.externalApplication);
                      } catch (_) {
                        Clipboard.setData(ClipboardData(text: idxUrl));
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open; URL copied'), backgroundColor: OrgColors.warning));
                      }
                    },
                    child: Text('Open', style: GoogleFonts.beVietnamPro()),
                  ),
                ]),
              ]),
            );
          }
          return Center(child: Text('Error: ${snap.error}', style: GoogleFonts.beVietnamPro()));
        }
        var docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState();
        }
        List<AnnouncementModel> all = docs.map((d) => AnnouncementModel.fromFirestore(d)).toList();
        // Sort client-side by timestamp (descending) to avoid requiring
        // a Firestore composite index for the `.where(...).orderBy(...)` query.
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
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
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
          Text(
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total announcements',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
          ),
          Row(children: [
            _PageButton(icon: Icons.chevron_left_rounded, enabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumButton(page: p, isActive: p == _currentPage, onTap: () => setState(() => _currentPage = p))),
            if (lastPage < totalPages) ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 12))),
              _PageNumButton(page: totalPages, isActive: _currentPage == totalPages, onTap: () => setState(() => _currentPage = totalPages)),
            ],
            const SizedBox(width: 4),
            _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Create/Edit Dialog
  // ─────────────────────────────────────────────────────────────────────────
  void _showAnnouncementDialog({AnnouncementModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    bool isPinned = existing?.isPinned ?? false;
    String? imageUrl = existing?.imageUrl;
    List<Attachment> attachments = List.from(existing?.attachments ?? []);
    bool isSubmitting = false;
    bool isUploadingImage = false;
    bool isUploadingFile = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 680,
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
                      decoration: BoxDecoration(color: Color.fromRGBO(255, 255, 255, 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(isEdit ? Icons.edit_rounded : Icons.campaign_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Announcement' : 'New Announcement',
                        style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
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
                          // Category
                          TextFormField(
                            controller: categoryCtrl,
                            decoration: _DS.inputDecoration('Category', hint: 'e.g. General, Event, Update', icon: Icons.category_outlined),
                            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          // Title
                          TextFormField(
                            controller: titleCtrl,
                            decoration: _DS.inputDecoration('Title', hint: 'Enter announcement title', icon: Icons.title),
                            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          // Content
                          TextFormField(
                            controller: contentCtrl,
                            maxLines: 6,
                            decoration: _DS.inputDecoration('Content', hint: 'Write your announcement here...', icon: Icons.description_outlined),
                            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          // Pinned toggle
                          Row(children: [
                            Switch(
                              value: isPinned,
                              onChanged: (val) => setDialogState(() => isPinned = val),
                              activeThumbColor: OrgColors.primaryDark,
                            ),
                            const SizedBox(width: 8),
                            Text('Pin this announcement', style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal)),
                          ]),
                          const SizedBox(height: 18),
                          // Image picker
                          _buildImagePicker(imageUrl, (newUrl) => setDialogState(() => imageUrl = newUrl), () => setDialogState(() => imageUrl = null), isUploadingImage, (v) => setDialogState(() => isUploadingImage = v)),
                          const SizedBox(height: 18),
                          // Attachments
                          _buildAttachmentsPicker(attachments, (newAtts) => setDialogState(() => attachments = newAtts), isUploadingFile, (v) => setDialogState(() => isUploadingFile = v)),
                          const SizedBox(height: 12),
                          // Video picker (uploads like other attachments)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
                                if (result == null || result.files.isEmpty) return;
                                setDialogState(() => isUploadingFile = true);
                                try {
                                  final file = result.files.first;
                                  if (file.bytes == null && file.path == null) throw 'Unable to read file';
                                  final name = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
                                  final ref = FirebaseStorage.instance.ref().child('announcements/${widget.orgId}/videos/$name');
                                  if (file.bytes != null) {
                                    await ref.putData(file.bytes!);
                                  } else if (file.path != null) {
                                    await ref.putFile(File(file.path!));
                                  }
                                  final url = await ref.getDownloadURL();
                                  final newAtt = Attachment(name: file.name, url: url);
                                  setDialogState(() => attachments = [...attachments, newAtt]);
                                } catch (e) {
                                  _showSnack('Video upload failed: $e', isError: true);
                                } finally {
                                  setDialogState(() => isUploadingFile = false);
                                }
                              },
                              icon: const Icon(Icons.videocam_outlined),
                              label: Text('Add Video', style: GoogleFonts.beVietnamPro()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: OrgColors.border)),
                    color: OrgColors.surface,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: OrgColors.borderSoft),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        ),
                        child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser!;
                            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                            final authorName = userDoc.data()?['name'] ?? user.email ?? 'Unknown';
                            final data = {
                              'orgId': widget.orgId,
                              'category': categoryCtrl.text.trim(),
                              'title': titleCtrl.text.trim(),
                              'content': contentCtrl.text.trim(),
                              'authorId': user.uid,
                              'authorName': authorName,
                              'attachments': attachments.map((a) => {'name': a.name, 'url': a.url}).toList(),
                              'imageUrl': imageUrl ?? '',
                              'pinned': isPinned,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };
                            if (isEdit) {
                              await FirebaseFirestore.instance.collection('announcements').doc(existing.id).update(data);
                              await activity_log.ActivityLogger.log(action: 'edit_announcement', module: 'announcements', details: {'orgId': widget.orgId, 'announcementId': existing.id});
                            } else {
                              data['timestamp'] = FieldValue.serverTimestamp();
                              await FirebaseFirestore.instance.collection('announcements').add(data);
                              await activity_log.ActivityLogger.log(action: 'create_announcement', module: 'announcements', details: {'orgId': widget.orgId, 'title': data['title']});
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) _showSnack(isEdit ? 'Announcement updated' : 'Announcement posted', isError: false);
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OrgColors.error));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OrgColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? 'Save Changes' : 'Post Announcement', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(String? currentUrl, Function(String) onImageSelected, VoidCallback onRemove, bool isUploading, Function(bool) setUploading) {
    if (currentUrl != null && currentUrl.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
            child: Image.network(currentUrl, width: double.infinity, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 160, color: OrgColors.lightGray, child: const Icon(Icons.broken_image))),
          ),
          Positioned(
            top: 8, right: 8,
            child: InkWell(
              onTap: onRemove,
              child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.6), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
        if (result == null) return;
        setUploading(true);
        try {
          final file = result.files.first;
          final bytes = file.bytes!;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final ref = FirebaseStorage.instance.ref().child('announcements/${widget.orgId}/images/$fileName');
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          onImageSelected(url);
        } catch (e) {
          _showSnack('Image upload failed: $e', isError: true);
        } finally {
          setUploading(false);
        }
      },
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: OrgColors.lightGray,
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          border: Border.all(color: OrgColors.borderSoft),
        ),
        child: isUploading
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: OrgColors.primaryDark)))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Color.fromRGBO(180, 83, 9, 0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.image_outlined, color: OrgColors.primaryDark)),
                const SizedBox(height: 8),
                Text('Click to upload banner image', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                const SizedBox(height: 2),
                Text('Recommended 1200×630 · PNG, JPG up to 5 MB', style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.textFaint)),
              ]),
      ),
    );
  }

  Widget _buildAttachmentsPicker(List<Attachment> attachments, Function(List<Attachment>) onAttachmentsChanged, bool isUploading, Function(bool) setUploading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final result = await FilePicker.platform.pickFiles(allowMultiple: true);
            if (result == null) return;
            setUploading(true);
            try {
              final newAtts = <Attachment>[];
              for (final file in result.files) {
                final bytes = file.bytes;
                final name = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
                final ref = FirebaseStorage.instance.ref().child('announcements/${widget.orgId}/attachments/$name');
                if (bytes != null) {
                  await ref.putData(bytes);
                } else if (file.path != null) {
                  await ref.putFile(File(file.path!));
                } else {
                  continue;
                }
                final url = await ref.getDownloadURL();
                newAtts.add(Attachment(name: file.name, url: url));
              }
              onAttachmentsChanged([...attachments, ...newAtts]);
            } catch (e) {
              _showSnack('Upload failed: $e', isError: true);
            } finally {
              setUploading(false);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: OrgColors.lightGray,
              borderRadius: BorderRadius.circular(_DS.radiusSm),
              border: Border.all(color: OrgColors.borderSoft),
            ),
            child: isUploading
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: OrgColors.primaryDark)))
                : Column(children: [
                    Icon(Icons.attach_file_rounded, size: 24, color: OrgColors.primaryDark),
                    const SizedBox(height: 6),
                    Text('Add attachments', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                  ]),
          ),
        ),
        const SizedBox(height: 10),
        ...attachments.asMap().entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8), border: Border.all(color: OrgColors.borderSoft)),
          child: Row(children: [
            const Icon(Icons.insert_drive_file_outlined, size: 18, color: OrgColors.info),
            const SizedBox(width: 8),
            Expanded(child: Text(e.value.name, style: GoogleFonts.beVietnamPro(fontSize: 12), overflow: TextOverflow.ellipsis)),
            InkWell(
              onTap: () {
                final newList = List<Attachment>.from(attachments)..removeAt(e.key);
                onAttachmentsChanged(newList);
              },
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 16, color: OrgColors.darkGray)),
            ),
          ]),
        )),
      ],
    );
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
    final hasImage = announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: OrgColors.border),
        boxShadow: _DS.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            Stack(children: [
              SizedBox(height: 180, width: double.infinity, child: Image.network(announcement.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: OrgColors.lightGray))),
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.45)])))),
              if (announcement.category.isNotEmpty)
                Positioned(bottom: 12, left: 16, child: _CategoryChip(label: announcement.category)),
              if (announcement.isPinned)
                Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: OrgColors.warning, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.push_pin, size: 12, color: Colors.white), const SizedBox(width: 4), Text('Pinned', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))]))),
            ]),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage && announcement.category.isNotEmpty) ...[
                  _CategoryChip(label: announcement.category),
                  const SizedBox(height: 12),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(announcement.title,
                          style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w800, color: OrgColors.charcoal, height: 1.3)),
                    ),
                    if (!hasImage && announcement.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.push_pin, size: 16, color: OrgColors.warning),
                      ),
                    PopupMenuButton<String>(
                      onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
                      offset: const Offset(0, 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusMd)),
                      icon: Container(width: 32, height: 32, decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: OrgColors.border)), child: const Icon(Icons.more_horiz_rounded, size: 18, color: OrgColors.darkGray)),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: OrgColors.darkGray), const SizedBox(width: 10), Text('Edit')])),
                        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: OrgColors.error), const SizedBox(width: 10), Text('Delete', style: TextStyle(color: OrgColors.error))])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: Color.fromRGBO(180, 83, 9, 0.1), child: Text(announcement.authorName.isNotEmpty ? announcement.authorName[0].toUpperCase() : '?', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: OrgColors.primaryDark))),
                  const SizedBox(width: 8),
                  Text(announcement.authorName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                  const SizedBox(width: 8),
                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: OrgColors.textFaint, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_timeAgo(announcement.timestamp), style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.textFaint)),
                ]),
                const SizedBox(height: 14),
                Text(announcement.content, style: GoogleFonts.beVietnamPro(fontSize: 14, height: 1.6, color: OrgColors.textMid)),
                if (announcement.attachments.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(20), border: Border.all(color: OrgColors.border)), child: Row(children: [const Icon(Icons.attach_file_rounded, size: 12), const SizedBox(width: 4), Text('${announcement.attachments.length} attachment(s)')])),
                  ]),
                  const SizedBox(height: 10),
                  ...announcement.attachments.map((att) => _AttachmentTile(attachment: att)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: OrgColors.accent, borderRadius: BorderRadius.circular(100)), child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)));
}

class _AttachmentTile extends StatelessWidget {
  final Attachment attachment;
  const _AttachmentTile({required this.attachment});
  @override
  Widget build(BuildContext context) {
    final name = attachment.name.toLowerCase();
    final isVideo = name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.webm') || name.endsWith('.mkv');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8), border: Border.all(color: OrgColors.border)),
      child: Row(children: [
        Icon(isVideo ? Icons.videocam_outlined : Icons.insert_drive_file_outlined, size: 18, color: OrgColors.info),
        const SizedBox(width: 10),
        Expanded(child: Text(attachment.name, style: GoogleFonts.beVietnamPro(fontSize: 13), overflow: TextOverflow.ellipsis)),
        if (isVideo)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => showDialog(context: context, builder: (_) => _VideoPreviewDialog(url: attachment.url)),
              child: const Icon(Icons.play_circle_outline_rounded, size: 18, color: OrgColors.primaryDark),
            ),
          ),
        InkWell(onTap: () { Clipboard.setData(ClipboardData(text: attachment.url)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied'), backgroundColor: OrgColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))); }, child: const Icon(Icons.copy_rounded, size: 16, color: OrgColors.info)),
      ]),
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  final String url;
  const _VideoPreviewDialog({required this.url});
  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _ready = true);
        _ctrl.play();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 720,
        height: 420,
        color: Colors.black,
        child: _ready
            ? Stack(children: [Center(child: AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl))), Positioned(bottom: 10, right: 10, child: IconButton(icon: Icon(_ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: () => setState(() => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play())) )])
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pagination widgets
// ─────────────────────────────────────────────────────────────────────────────
class _PageButton extends StatelessWidget {
  final IconData icon; final bool enabled; final VoidCallback onTap;
  const _PageButton({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 20, color: enabled ? OrgColors.textMid : OrgColors.textFaint)));
}

class _PageNumButton extends StatelessWidget {
  final int page; final bool isActive; final VoidCallback onTap;
  const _PageNumButton({required this.page, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: isActive ? OrgColors.primaryDark : Colors.transparent, borderRadius: BorderRadius.circular(6)), child: Text('$page', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal, color: isActive ? Colors.white : OrgColors.textMid))));
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class Attachment {
  final String name; final String url;
  const Attachment({required this.name, required this.url});
  Map<String, dynamic> toMap() => {'name': name, 'url': url};
}

class AnnouncementModel {
  final String id, category, title, content, authorId, authorName;
  final Timestamp timestamp;
  final List<Attachment> attachments;
  final String? imageUrl;
  final bool isPinned;

  const AnnouncementModel({
    required this.id, required this.category, required this.title, required this.content,
    required this.authorId, required this.authorName, required this.timestamp,
    required this.attachments, this.imageUrl, this.isPinned = false,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      category: d['category'] ?? '',
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      timestamp: d['timestamp'] as Timestamp,
      attachments: ((d['attachments'] as List?) ?? []).map((a) => Attachment(name: a['name'], url: a['url'])).toList(),
      imageUrl: d['imageUrl'] as String?,
      isPinned: d['pinned'] as bool? ?? false,
    );
  }
}