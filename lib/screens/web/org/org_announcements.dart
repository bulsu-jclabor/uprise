// lib/screens/web/org/org_announcements.dart
// Redesigned: Professional + Facebook-style feed
// Matches StudentAccounts design language exactly
// All Firestore parameters preserved for student-side compatibility

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../widgets/admin_export_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens — mirrors StudentAccounts exactly
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  // Primary brand
  static const Color primaryDark  = Color(0xFFEA580C);

  // Surfaces
  static const Color white        = Color(0xFFFFFFFF);
  static const Color surface      = Color(0xFFF8F9FB);
  static const Color pageBg       = Color(0xFFFBFCFE);

  // Borders
  static const Color border       = Color(0xFFE8ECF0);
  static const Color borderSoft   = Color(0xFFE2E6EA);

  // Text
  static const Color charcoal     = Color(0xFF1A202C);
  static const Color textMid      = Color(0xFF374151);
  static const Color darkGray     = Color(0xFF64748B);
  static const Color textFaint    = Color(0xFF9AA5B4);

  // Semantic
  static const Color success      = Color(0xFF059669);
  static const Color successBg    = Color(0xFFECFDF5);
  static const Color warning      = Color(0xFFFB923C);
  static const Color warningBg    = Color(0xFFFFFBEB);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorBg      = Color(0xFFFEF2F2);
  static const Color info         = Color(0xFF2563EB);
  static const Color infoBg       = Color(0xFFEFF6FF);
}

class _DS {
  static const double radiusSm   = 8;
  static const double radiusLg   = 16;
  static const double radiusPill = 100;

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.06),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> postShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.07),
      blurRadius: 8,
      offset: Offset(0, 2),
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
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: _C.textFaint)
          : null,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.darkGray),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint),
      filled: true,
      fillColor: _C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: _C.borderSoft, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: _C.borderSoft, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: _C.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: _C.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: _C.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable micro-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: _C.darkGray, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 28, fontWeight: FontWeight.w700, color: _C.charcoal)),
            ]),
          ),
        ]),
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
        color: _C.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.borderSoft),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _C.textFaint),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textMid),
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

Widget _audienceBadge(String audience) {
  final Map<String, _BadgeTheme> map = {
    'Public':       _BadgeTheme(_C.successBg, _C.success, Icons.public_rounded),
    'CICT Only':    _BadgeTheme(_C.infoBg, _C.info, Icons.school_rounded),
    'Members Only': _BadgeTheme(_C.warningBg, _C.warning, Icons.group_rounded),
  };
  final t = map[audience] ??
      _BadgeTheme(const Color(0xFFF3F4F6), const Color(0xFF6B7280), Icons.people_outline);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(_DS.radiusPill)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(t.icon, size: 11, color: t.fg),
      const SizedBox(width: 5),
      Text(audience,
          style: GoogleFonts.beVietnamPro(
              fontSize: 10, fontWeight: FontWeight.w700, color: t.fg, letterSpacing: 0.3)),
    ]),
  );
}

class _BadgeTheme {
  final Color bg, fg;
  final IconData icon;
  const _BadgeTheme(this.bg, this.fg, this.icon);
}

// Section label — same as StudentAccounts
Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: _C.primaryDark),
        const SizedBox(width: 8),
      ],
      Text(text,
          style: GoogleFonts.beVietnamPro(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: _C.primaryDark, letterSpacing: 0.3)),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: _C.borderSoft, thickness: 1)),
    ]),
  );
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
  String _filterMode  = 'All';
  int _currentPage    = 1;
  static const int _pageSize = 5;

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
          a.content.toLowerCase().contains(q)).toList();
    }
    if (_filterMode == 'Pinned') {
      out = out.where((a) => a.isPinned).toList();
    } else if (_filterMode == 'With Attachments') {
      out = out.where((a) => a.attachmentsBase64.isNotEmpty).toList();
    }
    return out;
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor: isError ? _C.error : _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
    ));
  }

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
                  decoration: BoxDecoration(
                      color: _C.errorBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: _C.error, size: 20),
                ),
                const SizedBox(width: 14),
                Text('Delete Announcement',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 17, fontWeight: FontWeight.w700, color: _C.charcoal)),
              ]),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to delete "${a.title}"? This action cannot be undone.',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: _C.darkGray),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.borderSoft),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textMid)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _C.error, foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: Text('Delete',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(a.id)
          .delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_announcement',
        module: 'announcements',
        details: {'orgId': widget.orgId, 'announcementId': a.id},
      );
      if (mounted) _snack('Announcement deleted successfully');
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    }
  }

  // ── Toggle pin ────────────────────────────────────────────────────────────
  Future<void> _togglePin(AnnouncementModel a) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(a.id)
          .update({'pinned': !a.isPinned});
      _snack(a.isPinned ? 'Unpinned' : 'Pinned announcement');
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final isTablet = width >= 720 && width < 1200;

    return Scaffold(
      backgroundColor: _C.pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(isMobile, isTablet),
          _buildToolbar(isMobile, isTablet),
          const SizedBox(height: 0),
          Expanded(child: _buildFeed()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Stats row (identical pattern to StudentAccounts) ──────────────────────
  Widget _buildStatsRow(bool isMobile, bool isTablet) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        int total = 0, pinned = 0, withAttachments = 0;
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            total++;
            if (d['pinned'] == true) pinned++;
            final atts = d['attachmentsBase64'] as List?;
            if (atts != null && atts.isNotEmpty) withAttachments++;
          }
        }

        final cards = [
          _StatCard(label: 'Total Posts', value: '$total', icon: Icons.campaign_rounded, color: _C.primaryDark),
          _StatCard(label: 'Pinned', value: '$pinned', icon: Icons.push_pin_rounded, color: _C.warning),
          _StatCard(label: 'With Files', value: '$withAttachments', icon: Icons.attach_file_rounded, color: _C.info),
        ];

        return Padding(
          padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0, 24, MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0, 0),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cards[0],
                    const SizedBox(height: 14),
                    cards[1],
                    const SizedBox(height: 14),
                    cards[2],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cards[0],
                    const SizedBox(width: 14),
                    cards[1],
                    const SizedBox(width: 14),
                    cards[2],
                  ],
                ),
        );
      },
    );
  }

  // ── Toolbar (mirrors StudentAccounts toolbar exactly) ─────────────────────
  Widget _buildToolbar(bool isMobile, bool isTablet) {
    final searchField = SizedBox(
      width: isMobile ? double.infinity : 280,
      height: 40,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search announcements…',
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _C.textFaint),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.borderSoft)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.borderSoft)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.primaryDark, width: 1.5)),
        ),
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _currentPage = 1;
        }),
      ),
    );

    final filterAndExport = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterDropdown(
          value: _filterMode,
          items: const ['All', 'Pinned', 'With Attachments'],
          onChanged: (v) => setState(() {
            _filterMode = v!;
            _currentPage = 1;
          }),
        ),
        const SizedBox(width: 10),
        AdminExportButton(
          label: 'Export',
          onSelected: (choice) async {
            try {
              final snap = await FirebaseFirestore.instance
                  .collection('announcements')
                  .where('orgId', isEqualTo: widget.orgId)
                  .get();
              final all = snap.docs.map((d) => AnnouncementModel.fromFirestore(d)).toList();
              final filtered = _filtered(all);
              _snack('Exported ${filtered.length} records');
            } catch (e) {
              _snack('Export failed: $e', isError: true);
            }
          },
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0, 20, MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 980) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                filterAndExport,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _FilterDropdown(
                  value: _filterMode,
                  items: const ['All', 'Pinned', 'With Attachments'],
                  onChanged: (v) => setState(() {
                    _filterMode = v!;
                    _currentPage = 1;
                  }),
                ),
                AdminExportButton(
                  label: 'Export',
                  onSelected: (choice) async {
                    try {
                      final snap = await FirebaseFirestore.instance
                          .collection('announcements')
                          .where('orgId', isEqualTo: widget.orgId)
                          .get();
                      final all = snap.docs.map((d) => AnnouncementModel.fromFirestore(d)).toList();
                      final filtered = _filtered(all);
                      _snack('Exported ${filtered.length} records');
                    } catch (e) {
                      _snack('Export failed: $e', isError: true);
                    }
                  },
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  // ── Feed shell (same card container as StudentAccounts table) ─────────────
  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.primaryDark));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: GoogleFonts.beVietnamPro()));
        }

        if (snap.data!.docs.isEmpty) return _buildEmptyState();

        var all = snap.data!.docs
            .map((d) => AnnouncementModel.fromFirestore(d))
            .toList();
        all.sort((a, b) {
          // Pinned always first
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.timestamp.toDate().compareTo(a.timestamp.toDate());
        });
        final filtered = _filtered(all);
        final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, filtered.length);
        final pageItems = filtered.isEmpty ? <AnnouncementModel>[] : filtered.sublist(start, end);

        final horizontalPadding = MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0;
        return Container(
          margin: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(children: [
            Expanded(
              child: pageItems.isEmpty
                  ? _buildEmptySearchState()
                  : _buildFeedContent(pageItems),
            ),
            _buildPaginationFooter(filtered.length, totalPages, start, end),
          ]),
        );
      },
    );
  }

  Widget _buildFeedContent(List<AnnouncementModel> items) {
    return CustomScrollView(
      slivers: [
        // Composer teaser (like Facebook's "What's on your mind?")
        SliverToBoxAdapter(child: _buildComposerTeaser()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _PostCard(
                announcement: items[i],
                onEdit: () => _showAnnouncementDialog(existing: items[i]),
                onDelete: () => _deleteAnnouncement(items[i]),
                onTogglePin: () => _togglePin(items[i]),
              ),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComposerTeaser() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.borderSoft),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Org avatar
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _C.primaryDark.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.campaign_rounded, size: 20, color: _C.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.border),
              ),
              child: Text(
                'What’s on your mind? Create an announcement for your members…',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.image_outlined, size: 16, color: _C.primaryDark),
                  const SizedBox(width: 6),
                  Text('Add photo', style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.primaryDark, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _showAnnouncementDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Create announcement',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final horizontalPadding = MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0;
    return Container(
      margin: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: _C.surface, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.campaign_outlined, size: 40, color: _C.textFaint),
          ),
          const SizedBox(height: 16),
          Text('No Announcements Yet',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _C.charcoal)),
          const SizedBox(height: 6),
          Text('Click "Create Announcement" to create your first post.',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.darkGray)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAnnouncementDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Create Announcement',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off_rounded, size: 48, color: _C.textFaint),
        const SizedBox(height: 12),
        Text('No matching announcements',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: _C.darkGray)),
      ]),
    );
  }

  Widget _buildPaginationFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage  = (firstPage + maxVisible - 1).clamp(1, totalPages);
    final pages   = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.border)),
        color: _C.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total announcements',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.darkGray),
          ),
          Row(children: [
            _PageBtn(
              icon: Icons.chevron_left_rounded,
              enabled: _currentPage > 1,
              onTap: () => setState(() => _currentPage--),
            ),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumBtn(
                  page: p,
                  isActive: p == _currentPage,
                  onTap: () => setState(() => _currentPage = p),
                )),
            const SizedBox(width: 4),
            _PageBtn(
              icon: Icons.chevron_right_rounded,
              enabled: _currentPage < totalPages,
              onTap: () => setState(() => _currentPage++),
            ),
          ]),
        ],
      ),
    );
  }

  // ==========================================================================
  // CREATE / EDIT DIALOG
  // ==========================================================================
  void _showAnnouncementDialog({AnnouncementModel? existing}) {
    final isEdit = existing != null;
    final formKey    = GlobalKey<FormState>();
    final titleCtrl  = TextEditingController(text: existing?.title ?? '');
    final contentCtrl= TextEditingController(text: existing?.content ?? '');
    bool isPinned    = existing?.isPinned ?? false;
    String? imageBase64 = existing?.imageBase64;
    List<AttachmentBase64> attachments = List.from(existing?.attachmentsBase64 ?? []);
    String targetAudience = existing?.targetAudience ?? 'Members Only';
    bool isSubmitting = false;
    bool isScheduled  = existing?.scheduledPublishDate != null;
    DateTime? scheduledDate;
    TimeOfDay? scheduledTime;

    if (existing != null && existing.scheduledPublishDate != null) {
      scheduledDate = existing.scheduledPublishDate!.toDate();
      scheduledTime = TimeOfDay.fromDateTime(scheduledDate);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 620,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
                  decoration: const BoxDecoration(
                    color: _C.primaryDark,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.campaign_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Announcement' : 'Create Announcement',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ]),
                ),

                // ── Body ────────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Post Details', icon: Icons.article_outlined),
                          TextFormField(
                            controller: titleCtrl,
                            decoration: _DS.inputDecoration('Title *',
                                hint: 'Enter announcement title', icon: Icons.title_rounded),
                            style: GoogleFonts.beVietnamPro(fontSize: 13),
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: contentCtrl,
                            maxLines: 5,
                            decoration: _DS.inputDecoration('Content *',
                                hint: 'Write your announcement here…',
                                icon: Icons.description_outlined),
                            style: GoogleFonts.beVietnamPro(fontSize: 13),
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Content is required' : null,
                          ),
                          const SizedBox(height: 20),

                          _sectionLabel('Banner Image', icon: Icons.image_outlined),
                          _buildImagePicker(
                              imageBase64,
                              (v) => setDlg(() => imageBase64 = v),
                              () => setDlg(() => imageBase64 = null)),
                          const SizedBox(height: 20),

                          _sectionLabel('Attachments', icon: Icons.attach_file_rounded),
                          _buildAttachmentsPicker(
                              attachments, (v) => setDlg(() => attachments = v)),
                          const SizedBox(height: 20),

                          _sectionLabel('Settings', icon: Icons.tune_rounded),
                          // Audience dropdown
                          Container(
                            decoration: BoxDecoration(
                              color: _C.surface,
                              borderRadius: BorderRadius.circular(_DS.radiusSm),
                              border: Border.all(color: _C.borderSoft),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: targetAudience,
                              decoration: InputDecoration(
                                labelText: 'Target Audience',
                                labelStyle: GoogleFonts.beVietnamPro(
                                    fontSize: 13, color: _C.darkGray),
                                prefixIcon: const Icon(Icons.people_outline,
                                    size: 18, color: _C.textFaint),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              items: ['Public', 'CICT Only', 'Members Only']
                                  .map((o) => DropdownMenuItem(
                                        value: o,
                                        child: Row(children: [
                                          Icon(
                                            o == 'Public'
                                                ? Icons.public_rounded
                                                : o == 'CICT Only'
                                                    ? Icons.school_rounded
                                                    : Icons.group_rounded,
                                            size: 15,
                                            color: _C.primaryDark,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(o,
                                              style: GoogleFonts.beVietnamPro(
                                                  fontSize: 13)),
                                        ]),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setDlg(() => targetAudience = v!),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Schedule
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _C.surface,
                              borderRadius: BorderRadius.circular(_DS.radiusSm),
                              border: Border.all(color: _C.borderSoft),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Switch(
                                  value: isScheduled,
                                  onChanged: (val) => setDlg(() {
                                    isScheduled = val;
                                    if (!isScheduled) {
                                      scheduledDate = null;
                                      scheduledTime = null;
                                    }
                                  }),
                                  activeColor: _C.primaryDark,
                                ),
                                const SizedBox(width: 8),
                                Text('Schedule for later',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: _C.charcoal)),
                              ]),
                              if (isScheduled) ...[
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final p = await showDatePicker(
                                          context: ctx,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 365)),
                                        );
                                        if (p != null)
                                          setDlg(() => scheduledDate = p);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(_DS.radiusSm),
                                          border: Border.all(color: _C.borderSoft),
                                        ),
                                        child: Row(children: [
                                          const Icon(Icons.calendar_today_rounded,
                                              size: 15, color: _C.primaryDark),
                                          const SizedBox(width: 10),
                                          Text(
                                            scheduledDate != null
                                                ? DateFormat('MMM dd, yyyy')
                                                    .format(scheduledDate!)
                                                : 'Select date',
                                            style: GoogleFonts.beVietnamPro(fontSize: 13),
                                          ),
                                        ]),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final p = await showTimePicker(
                                            context: ctx,
                                            initialTime: TimeOfDay.now());
                                        if (p != null)
                                          setDlg(() => scheduledTime = p);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(_DS.radiusSm),
                                          border: Border.all(color: _C.borderSoft),
                                        ),
                                        child: Row(children: [
                                          const Icon(Icons.access_time_rounded,
                                              size: 15, color: _C.primaryDark),
                                          const SizedBox(width: 10),
                                          Text(
                                            scheduledTime != null
                                                ? scheduledTime!.format(ctx)
                                                : 'Select time',
                                            style: GoogleFonts.beVietnamPro(fontSize: 13),
                                          ),
                                        ]),
                                      ),
                                    ),
                                  ),
                                ]),
                              ],
                            ]),
                          ),
                          const SizedBox(height: 14),

                          // Pin toggle
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isPinned
                                  ? _C.warningBg
                                  : _C.surface,
                              borderRadius: BorderRadius.circular(_DS.radiusSm),
                              border: Border.all(
                                  color: isPinned
                                      ? _C.warning.withOpacity(0.4)
                                      : _C.borderSoft),
                            ),
                            child: Row(children: [
                              Switch(
                                value: isPinned,
                                onChanged: (v) => setDlg(() => isPinned = v),
                                activeColor: _C.warning,
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.push_pin_rounded,
                                  size: 15, color: _C.warning),
                              const SizedBox(width: 6),
                              Text('Pin this announcement',
                                  style: GoogleFonts.beVietnamPro(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _C.charcoal)),
                              const Spacer(),
                              Text('Pinned posts appear at the top of the feed',
                                  style: GoogleFonts.beVietnamPro(
                                      fontSize: 11, color: _C.darkGray)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Footer ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _C.border)),
                    color: _C.surface,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _C.borderSoft),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13, color: _C.textMid)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setDlg(() => isSubmitting = true);
                                try {
                                  final user = FirebaseAuth.instance.currentUser!;
                                  final userDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .get();
                                  final authorName =
                                      userDoc.data()?['name'] ?? user.email ?? 'Unknown';

                                  Timestamp? scheduledTs;
                                  if (isScheduled &&
                                      scheduledDate != null &&
                                      scheduledTime != null) {
                                    scheduledTs = Timestamp.fromDate(DateTime(
                                      scheduledDate!.year,
                                      scheduledDate!.month,
                                      scheduledDate!.day,
                                      scheduledTime!.hour,
                                      scheduledTime!.minute,
                                    ));
                                  }

                                  // ─ All original Firestore fields preserved ─
                                  final data = {
                                    'orgId': widget.orgId,
                                    'title': titleCtrl.text.trim(),
                                    'content': contentCtrl.text.trim(),
                                    'authorId': user.uid,
                                    'authorName': authorName,
                                    'attachmentsBase64': attachments
                                        .map((a) => {
                                              'name': a.name,
                                              'base64': a.base64,
                                              'size': a.size,
                                            })
                                        .toList(),
                                    'imageBase64': imageBase64 ?? '',
                                    'pinned': isPinned,
                                    'targetAudience': targetAudience,
                                    'isScheduled': isScheduled,
                                    'scheduledPublishDate': scheduledTs,
                                    'isPublished': !isScheduled,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };

                                  if (isEdit) {
                                    await FirebaseFirestore.instance
                                        .collection('announcements')
                                        .doc(existing.id)
                                        .update(data);
                                  } else {
                                    data['timestamp'] = FieldValue.serverTimestamp();
                                    await FirebaseFirestore.instance
                                        .collection('announcements')
                                        .add(data);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    _snack(isEdit
                                        ? 'Announcement updated'
                                        : isScheduled
                                            ? 'Announcement scheduled'
                                            : 'Announcement posted');
                                  }
                                } catch (e) {
                                  setDlg(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: _C.error,
                                    ));
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                isEdit
                                    ? 'Save Changes'
                                    : isScheduled
                                        ? 'Schedule'
                                        : 'Share',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
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

  // ── Image picker ──────────────────────────────────────────────────────────
  Widget _buildImagePicker(
    String? currentBase64,
    Function(String) onSelected,
    VoidCallback onRemove,
  ) {
    if (currentBase64 != null && currentBase64.isNotEmpty) {
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          child: Image.memory(
            base64Decode(currentBase64),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 220,
              color: _C.surface,
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        Positioned(
          top: 8, right: 8,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ]);
    }

    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform
            .pickFiles(type: FileType.image, withData: true);
        if (result == null) return;
        try {
          final bytes = result.files.first.bytes!;
          if (bytes.length > 5 * 1024 * 1024) {
            _snack('Image too large! Max 5MB', isError: true);
            return;
          }
          onSelected(base64Encode(bytes));
          _snack('Image uploaded');
        } catch (e) {
          _snack('Upload failed: $e', isError: true);
        }
      },
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          border: Border.all(color: _C.borderSoft),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: _C.primaryDark.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.image_outlined, color: _C.primaryDark),
          ),
          const SizedBox(height: 8),
          Text('Click to upload banner image',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _C.charcoal)),
          Text('PNG, JPG up to 5MB',
              style: GoogleFonts.beVietnamPro(fontSize: 11, color: _C.textFaint)),
        ]),
      ),
    );
  }

  // ── Attachments picker ────────────────────────────────────────────────────
  Widget _buildAttachmentsPicker(
    List<AttachmentBase64> attachments,
    Function(List<AttachmentBase64>) onChanged,
  ) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () async {
          final result = await FilePicker.platform
              .pickFiles(allowMultiple: true, withData: true);
          if (result == null) return;
          try {
            final newAtts = <AttachmentBase64>[];
            for (final file in result.files) {
              final bytes = file.bytes!;
              if (bytes.length > 700 * 1024) {
                _snack('${file.name} exceeds 700 KB', isError: true);
                continue;
              }
              newAtts.add(AttachmentBase64(
                name: file.name,
                base64: base64Encode(bytes),
                size: '${(bytes.length / 1024).toStringAsFixed(1)} KB',
              ));
            }
            onChanged([...attachments, ...newAtts]);
            if (newAtts.isNotEmpty) _snack('${newAtts.length} file(s) attached');
          } catch (e) {
            _snack('Upload failed: $e', isError: true);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(_DS.radiusSm),
            border: Border.all(color: _C.borderSoft),
          ),
          child: Column(children: [
            const Icon(Icons.attach_file_rounded, size: 22, color: _C.primaryDark),
            const SizedBox(height: 4),
            Text('Add attachments',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _C.charcoal)),
            Text('PDF, DOC, DOCX, TXT, JPG, PNG — max 700 KB each',
                style: GoogleFonts.beVietnamPro(fontSize: 10, color: _C.textFaint)),
          ]),
        ),
      ),
      ...attachments.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.borderSoft),
            ),
            child: Row(children: [
              const Icon(Icons.insert_drive_file_outlined, size: 18, color: _C.info),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(e.value.name,
                      style: GoogleFonts.beVietnamPro(fontSize: 12))),
              if (e.value.size != null)
                Text(e.value.size!,
                    style: GoogleFonts.beVietnamPro(fontSize: 10, color: _C.textFaint)),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: _C.darkGray),
                onPressed: () => onChanged([...attachments]..removeAt(e.key)),
              ),
            ]),
          )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post Card — Facebook-style post
// ─────────────────────────────────────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final AnnouncementModel announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const _PostCard({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    if (diff.inDays < 30)    return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('MMM dd, yyyy').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final hasImage = a.imageBase64 != null && a.imageBase64!.isNotEmpty;
    final contentLines = a.content.split('\n');
    final isLong = a.content.length > 280 || contentLines.length > 4;
    final truncated = isLong && !_expanded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.isPinned ? _C.warning.withOpacity(0.4) : _C.border,
          width: a.isPinned ? 1.5 : 1,
        ),
        boxShadow: _DS.postShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Pinned indicator strip ──────────────────────────────────────────
        if (a.isPinned)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: _C.warningBg,
            child: Row(children: [
              const Icon(Icons.push_pin_rounded, size: 13, color: _C.warning),
              const SizedBox(width: 6),
              Text('Pinned Announcement',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.warning,
                      letterSpacing: 0.3)),
            ]),
          ),

        // ── Post header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Author avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _C.primaryDark.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  a.authorName.isNotEmpty
                      ? a.authorName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _C.primaryDark),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Author info + timestamp
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.authorName,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _C.charcoal)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 12, color: _C.textFaint),
                  const SizedBox(width: 4),
                  Text(_timeAgo(a.timestamp),
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11, color: _C.textFaint)),
                  const SizedBox(width: 8),
                  _audienceBadge(a.targetAudience),
                  if (a.isScheduled && !a.isPublished) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.infoBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.schedule_rounded,
                            size: 10, color: _C.info),
                        const SizedBox(width: 4),
                        Text('Scheduled',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _C.info)),
                      ]),
                    ),
                  ],
                ]),
              ]),
            ),
            // Actions menu
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') widget.onEdit();
                if (v == 'delete') widget.onDelete();
                if (v == 'pin') widget.onTogglePin();
              },
              icon: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_horiz_rounded,
                    size: 18, color: _C.darkGray),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 4,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_outlined,
                        size: 15, color: _C.darkGray),
                    const SizedBox(width: 10),
                    Text('Edit',
                        style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'pin',
                  child: Row(children: [
                    Icon(
                      a.isPinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                      size: 15,
                      color: _C.warning,
                    ),
                    const SizedBox(width: 10),
                    Text(a.isPinned ? 'Unpin' : 'Pin',
                        style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 15, color: _C.error),
                    const SizedBox(width: 10),
                    Text('Delete',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13, color: _C.error)),
                  ]),
                ),
              ],
            ),
          ]),
        ),

        // ── Title ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(a.title,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.charcoal,
                  height: 1.3)),
        ),

        // ── Content ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              truncated
                  ? '${a.content.substring(0, a.content.length.clamp(0, 280))}…'
                  : a.content,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14, height: 1.65, color: _C.textMid),
            ),
            if (isLong) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'See less' : 'See more',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.primaryDark),
                ),
              ),
            ],
          ]),
        ),

        // ── Banner image ─────────────────────────────────────────────────────
        if (hasImage) ...[
          const SizedBox(height: 12),
          Image.memory(
            base64Decode(a.imageBase64!),
            width: double.infinity,
            height: 280,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 280, color: _C.surface,
              child: const Icon(Icons.broken_image, color: _C.textFaint),
            ),
          ),
        ],

        // ── Attachments ──────────────────────────────────────────────────────
        if (a.attachmentsBase64.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.attach_file_rounded,
                    size: 14, color: _C.darkGray),
                const SizedBox(width: 6),
                Text(
                  '${a.attachmentsBase64.length} attachment${a.attachmentsBase64.length > 1 ? 's' : ''}',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.darkGray),
                ),
              ]),
              const SizedBox(height: 8),
              ...a.attachmentsBase64.map((att) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.infoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _C.info.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.insert_drive_file_outlined,
                          size: 16, color: _C.info),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(att.name,
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _C.info))),
                      if (att.size != null)
                        Text(att.size!,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 10, color: _C.textFaint)),
                    ]),
                  )),
            ]),
          ),
        ],

        // ── Footer divider + meta ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 12, color: _C.textFaint),
            const SizedBox(width: 5),
            Text(
              DateFormat('MMMM dd, yyyy • h:mm a')
                  .format(a.timestamp.toDate()),
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11, color: _C.textFaint),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pagination helpers
// ─────────────────────────────────────────────────────────────────────────────
class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 20,
            color: enabled ? _C.textMid : const Color(0xFFD1D5DB)),
      ),
    );
  }
}

class _PageNumBtn extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumBtn({required this.page, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? _C.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$page',
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive ? Colors.white : _C.textMid,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models — identical to original (full Firestore compatibility)
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
      attachments = attsList
          .map((a) => AttachmentBase64(
                name: a['name'] ?? '',
                base64: a['base64'] ?? '',
                size: a['size'],
              ))
          .toList();
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