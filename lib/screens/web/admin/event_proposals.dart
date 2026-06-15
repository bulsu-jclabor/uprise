import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/platform_file_utils.dart' as platform_file_utils;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

// Helper for image handling (copied from adviser_roles.dart)
ImageProvider _imageProviderFromUrl(String url) {
  if (url.startsWith('data:image')) {
    final base64Part = url.split(',').last;
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
}

Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  return Image(
    image: _imageProviderFromUrl(url),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: UpriseColors.primaryDark),
        const SizedBox(width: 8),
      ],
      Text(
        text,
        style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: UpriseColors.primaryDark,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
    ]),
  );
}

Widget _statusBadge(String status) {
  const Map<String, _BadgeStyle> styles = {
    'approved': _BadgeStyle(Color(0xFFECFDF5), Color(0xFF059669), 'APPROVED'),
    'pending':  _BadgeStyle(Color(0xFFFFFBEB), Color(0xFFFB923C), 'PENDING'),
    'rejected': _BadgeStyle(Color(0xFFFEF2F2), Color(0xFFDC2626), 'REJECTED'),
    'archived': _BadgeStyle(Color(0xFFF3F4F6), Color(0xFF6B7280), 'ARCHIVED'),
  };
  final s = styles[status.toLowerCase()] ??
      const _BadgeStyle(Color(0xFFF3F4F6), Color(0xFF6B7280), '—');
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: s.bg,
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Text(
      s.label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: s.fg,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Org Avatar with Logo (same as adviser_roles.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _OrgAvatar extends StatelessWidget {
  final String name;
  final String? logoUrl;
  const _OrgAvatar({required this.name, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        child: _buildImageWidget(logoUrl!, width: 34, height: 34, fit: BoxFit.cover),
      );
    }
    // Fallback to initials
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_DS.radiusSm),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: UpriseColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class EventProposals extends StatefulWidget {
  const EventProposals({super.key});

  @override
  State<EventProposals> createState() => _EventProposalsState();
}

class _EventProposalsState extends State<EventProposals> {
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Cache for organization logos
  final Map<String, String> _orgLogoCache = {};

  // Helper to check if widget is still mounted
  bool get _isMounted => mounted;

  // Fetch org logo by orgId
  Future<String?> _fetchOrgLogo(String orgId) async {
    if (_orgLogoCache.containsKey(orgId)) {
      return _orgLogoCache[orgId];
    }
    
    try {
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      
      if (orgDoc.exists) {
        final data = orgDoc.data() as Map<String, dynamic>;
        final logoUrl = data['logoUrl'] as String? ?? '';
        _orgLogoCache[orgId] = logoUrl;
        return logoUrl;
      }
    } catch (e) {
      debugPrint('Error fetching org logo for $orgId: $e');
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(isMobile, isTablet),
          _buildToolbar(isMobile, isTablet),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(child: _buildTable(isMobile, isTablet)),
          SizedBox(height: isMobile ? 16 : 24),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isMobile, bool isTablet) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('event_proposals').snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0, archived = 0;
        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final status = (doc.data() as Map)['status'] ?? 'pending';
            if (status == 'pending')  pending++;
            if (status == 'approved') approved++;
            if (status == 'rejected') rejected++;
            if (status == 'archived') archived++;
          }
        }
        final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 28.0);
        final cardGap = isMobile ? 8.0 : 14.0;
        final statCards = [
          _StatCard(
            label: 'Total Proposals',
            value: '$total',
            icon: Icons.event_note_rounded,
            color: UpriseColors.primaryDark,
          ),
          _StatCard(
            label: 'Approved',
            value: '$approved',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF059669),
          ),
          _StatCard(
            label: 'Pending',
            value: '$pending',
            icon: Icons.pending_rounded,
            color: const Color(0xFFFB923C),
          ),
          _StatCard(
            label: 'Rejected',
            value: '$rejected',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFDC2626),
          ),
          _StatCard(
            label: 'Archived',
            value: '$archived',
            icon: Icons.archive_rounded,
            color: const Color(0xFF6B7280),
          ),
        ];

        return Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
          child: isMobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      statCards.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(right: index < statCards.length - 1 ? cardGap : 0),
                        child: SizedBox(width: 220, child: statCards[index]),
                      ),
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    statCards.length,
                    (index) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index < statCards.length - 1 ? cardGap : 0),
                        child: statCards[index],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolbar(bool isMobile, bool isTablet) {
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 28.0);
    final itemGap = isMobile ? 10.0 : 12.0;

    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search proposal…',
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
        ),
        onChanged: (_) => setState(() => _currentPage = 1),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 16 : 20, horizontalPadding, 0),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                SizedBox(height: itemGap),
                _FilterDropdown(
                  value: _statusFilter,
                  items: const ['All', 'Pending', 'Approved', 'Rejected', 'Archived'],
                  hint: 'Status',
                  icon: Icons.tune_rounded,
                  onChanged: (v) => setState(() {
                    _statusFilter = v!;
                    _currentPage = 1;
                  }),
                ),
                SizedBox(height: itemGap),
                _ExportProposalsButton(
                  statusFilter: _statusFilter,
                  searchTerm: _searchController.text.trim(),
                ),
              ],
            )
          : Row(children: [
              Expanded(child: searchField),
              SizedBox(width: itemGap),
              _FilterDropdown(
                value: _statusFilter,
                items: const ['All', 'Pending', 'Approved', 'Rejected', 'Archived'],
                hint: 'Status',
                icon: Icons.tune_rounded,
                onChanged: (v) => setState(() {
                  _statusFilter = v!;
                  _currentPage = 1;
                }),
              ),
              SizedBox(width: itemGap),
              _ExportProposalsButton(
                statusFilter: _statusFilter,
                searchTerm: _searchController.text.trim(),
              ),
            ]),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────
  Widget _buildTable(bool isMobile, bool isTablet) {
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 28.0);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('event_proposals')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data!.docs;

        if (_statusFilter == 'All') {
          docs = docs
              .where((d) => (d.data() as Map)['status'] != 'archived')
              .toList();
        } else {
          docs = docs
              .where((d) => (d.data() as Map)['status'] == _statusFilter.toLowerCase())
              .toList();
        }

        final _searchTerm = _searchController.text.trim().toLowerCase();
        if (_searchTerm.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['title'] ?? '').toString().toLowerCase().contains(_searchTerm) ||
                (data['orgName'] ?? '').toString().toLowerCase().contains(_searchTerm) ||
                (data['submittedBy'] ?? '').toString().toLowerCase().contains(_searchTerm);
          }).toList();
        }

        final totalPages = docs.isEmpty ? 1 : (docs.length / _pageSize).ceil();
        final safePage   = _currentPage.clamp(1, totalPages);
        final start      = (safePage - 1) * _pageSize;
        final end        = (start + _pageSize).clamp(0, docs.length);
        final pageDocs   = docs.isEmpty ? [] : docs.sublist(start, end);

        final tableContent = Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
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
                        return _buildProposalRow(
                          docId: pageDocs[i].id,
                          data: data,
                          isLast: i == pageDocs.length - 1,
                        );
                      },
                    ),
            ),
            _buildFooter(docs.length, totalPages, start, end),
          ]),
        );

        return isMobile
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tableContent,
              )
            : tableContent;
      },
    );
  }

  // NEW HEADER: Organization first, then Event Title
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFFB923C), width: 1)),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: _headerCell('ORGANIZATION')),
        Expanded(flex: 3, child: _headerCell('EVENT TITLE')),
        Expanded(flex: 2, child: _headerCell('CATEGORY')),
        Expanded(flex: 2, child: _headerCell('DATE')),
        Expanded(flex: 1, child: _headerCell('STATUS')),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: _headerCell('ACTIONS'),
          ),
        ),
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

  Widget _buildProposalRow({
    required String docId,
    required Map<String, dynamic> data,
    required bool isLast,
  }) {
    final status  = (data['status'] ?? 'pending') as String;
    final dateStr = _formatDate(data['date']);
    final orgId = data['orgId'] ?? '';
    final orgName = data['orgName'] ?? '—';
    final orgLogoUrl = data['orgLogoUrl'] as String?;

    return FutureBuilder<String?>(
      future: _fetchOrgLogo(orgId),
      builder: (context, logoSnapshot) {
        final logoUrl = orgLogoUrl ?? (logoSnapshot.data ?? '');
        
        return InkWell(
          hoverColor: const Color(0xFFF8F9FB),
          onTap: () => _showProposalDetailDialog(docId, data),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(children: [
              // ORGANIZATION column (with logo) - NOW FIRST
              Expanded(
                flex: 2,
                child: Row(children: [
                  _OrgAvatar(name: orgName, logoUrl: logoUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      orgName,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              // EVENT TITLE column - title only, no category subtitle
              Expanded(
                flex: 3,
                child: Text(
                  data['title'] ?? '—',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // CATEGORY column
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data['category'] ?? '—',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: UpriseColors.primaryDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // DATE column
              Expanded(
                flex: 2,
                child: Text(
                  dateStr,
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // STATUS column
              Expanded(flex: 1, child: _statusBadge(status)),
              // ============ ACTIONS COLUMN - CORRECTED LOGIC ============
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // View button - always visible
                    _ActionIconButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'View Details',
                      onTap: () => _showProposalDetailDialog(docId, data),
                    ),
                    const SizedBox(width: 4),
                    
                    // For PENDING only: Show Approve and Reject buttons
                    if (status == 'pending') ...[
                      _ActionIconButton(
                        icon: Icons.check_circle_outline_rounded,
                        tooltip: 'Approve',
                        color: const Color(0xFF059669),
                        onTap: () => _confirmSetStatus(docId, data['title'] ?? 'this event', 'approved'),
                      ),
                      const SizedBox(width: 4),
                      _ActionIconButton(
                        icon: Icons.cancel_outlined,
                        tooltip: 'Reject',
                        color: const Color(0xFFDC2626),
                        onTap: () => _confirmSetStatus(docId, data['title'] ?? 'this event', 'rejected'),
                      ),
                      const SizedBox(width: 4),
                    ],
                    
                    // Archive button - visible for all except archived
                    if (status != 'archived')
                      _ActionIconButton(
                        icon: Icons.archive_outlined,
                        tooltip: 'Archive',
                        color: const Color(0xFF6B7280),
                        onTap: () => _confirmSetStatus(docId, data['title'] ?? 'this event', 'archived'),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFF9AA5B4)),
        ),
        const SizedBox(height: 16),
        Text(
          'No proposals found',
          style: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Try adjusting your filters or wait for new submissions.',
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
        ),
      ]),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage  = (firstPage + maxVisible - 1).clamp(1, totalPages);
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
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total proposals',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          Row(children: [
            _PageButton(
              icon: Icons.chevron_left_rounded,
              enabled: _currentPage > 1,
              onTap: () => setState(() => _currentPage--),
            ),
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
                    style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12)),
              ),
              _PageNumButton(
                page: totalPages,
                isActive: _currentPage == totalPages,
                onTap: () => setState(() => _currentPage = totalPages),
              ),
            ],
            const SizedBox(width: 4),
            _PageButton(
              icon: Icons.chevron_right_rounded,
              enabled: _currentPage < totalPages,
              onTap: () => setState(() => _currentPage++),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────

  void _confirmSetStatus(String docId, String title, String newStatus) {
    final Map<String, _ConfirmStyle> styles = {
      'approved': _ConfirmStyle(
        icon: Icons.check_circle_outline_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
        btnColor: const Color(0xFF059669),
        heading: 'Approve Proposal',
        body: 'Are you sure you want to approve "$title"? This will automatically add it to the calendar.',
        btnLabel: 'Approve',
      ),
      'rejected': _ConfirmStyle(
        icon: Icons.cancel_outlined,
        iconBg: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFDC2626),
        btnColor: const Color(0xFFDC2626),
        heading: 'Reject Proposal',
        body: 'Are you sure you want to reject "$title"? This action can be reversed.',
        btnLabel: 'Reject',
      ),
      'archived': _ConfirmStyle(
        icon: Icons.archive_outlined,
        iconBg: const Color(0xFFF3F4F6),
        iconColor: const Color(0xFF6B7280),
        btnColor: const Color(0xFF6B7280),
        heading: 'Archive Proposal',
        body: 'Are you sure you want to archive "$title"?',
        btnLabel: 'Archive',
      ),
    };
    final s = styles[newStatus]!;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: s.iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(s.icon, color: s.iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Text(s.heading,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
              ]),
              const SizedBox(height: 16),
              Text(s.body,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E6EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    
                    if (newStatus == 'approved') {
                      await _createEventFromProposal(docId);
                      _showWetSignSchedulingPopup(docId, title);
                    } else {
                      await _setStatus(docId, title, newStatus);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: s.btnColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text(s.btnLabel,
                      style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showWetSignSchedulingPopup(String proposalId, String title) {
    final _dateCtrl = TextEditingController();
    final _startTimeCtrl = TextEditingController();
    final _endTimeCtrl = TextEditingController();
    final _locationCtrl = TextEditingController(text: "Dean's Office");
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
                        'Schedule Wet Sign',
                        style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text(
                    'Set your office availability for the organization to sign documents.',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: _dateCtrl,
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
                        _dateCtrl.text = DateFormat('MM/dd/yyyy').format(picked);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  
                  TextFormField(
                    controller: _startTimeCtrl,
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
                        _startTimeCtrl.text = picked.format(ctx);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  
                  TextFormField(
                    controller: _endTimeCtrl,
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
                        _endTimeCtrl.text = picked.format(ctx);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'Office Location *',
                      hintText: 'e.g., Dean\'s Office Room 101',
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
                          _setStatus(proposalId, title, 'approved');
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
                          
                          await _saveWetSignSchedule(
                            proposalId: proposalId,
                            title: title,
                            startDateTime: startDateTime,
                            endDateTime: endDateTime,
                            location: _locationCtrl.text.trim(),
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

  Future<void> _saveWetSignSchedule({
    required String proposalId,
    required String title,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String location,
  }) async {
    try {
      final wetSignData = {
        'startDateTime': Timestamp.fromDate(startDateTime),
        'endDateTime': Timestamp.fromDate(endDateTime),
        'location': location,
        'status': 'scheduled',
        'scheduledBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'scheduledAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('event_proposals')
          .doc(proposalId)
          .update({
        'status': 'approved',
        'wetSignSchedule': wetSignData,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      
      await activity_log.ActivityLogger.log(
        action: 'schedule_wet_sign',
        module: 'Event Management',
        details: {
          'proposalId': proposalId,
          'title': title,
          'startDateTime': startDateTime.toIso8601String(),
          'location': location,
        },
      );
      
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Proposal approved and wet sign scheduled!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error saving wet sign schedule: $e');
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Proposal approved but wet sign scheduling failed: $e'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _createEventFromProposal(String proposalId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('event_proposals')
          .doc(proposalId)
          .get();
      
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      
      final title = data['title'] ?? 'Untitled Event';
      final description = data['description'] ?? '';
      final location = data['location'] ?? 'TBA';
      final category = data['category'] ?? 'Other';
      final orgId = data['orgId'] ?? '';
      final orgName = data['orgName'] ?? 'Unknown Organization';
      final proposalDate = data['date'] as Timestamp?;
      final date = proposalDate?.toDate() ?? DateTime.now();
      final timeStr = data['time'] ?? '09:00 AM';
      
      String startTime = timeStr;
      String endTime = _addOneHourToTimeString(timeStr);
      
      final int capacity = 100;
      final String guestSpeaker = 'TBA';
      final List<String> resources = [];
      final List<String> labPreparation = [];
      final List<String> tags = [];
      
      final eventData = {
        'orgId': orgId,
        'orgName': orgName,
        'title': title,
        'description': description,
        'location': location,
        'category': category,
        'date': Timestamp.fromDate(date),
        'startTime': startTime,
        'endTime': endTime,
        'capacity': capacity,
        'guestSpeaker': guestSpeaker,
        'resources': resources,
        'labPreparation': labPreparation,
        'tags': tags,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'createdFromProposalId': proposalId,
      };
      
      await FirebaseFirestore.instance.collection('events').add(eventData);

      // Notify all org members about the newly approved event
      () async {
        try {
          await NotificationService.sendToOrgMembers(
            orgId: orgId,
            title: 'New Event: $title',
            body: 'An event on ${DateFormat('MMM dd, yyyy').format(date)} has been approved and added to the calendar.',
            type: 'event_approved',
            data: {'eventTitle': title, 'eventDate': date.toIso8601String()},
          );
        } catch (_) {}
      }();

      await activity_log.ActivityLogger.log(
        action: 'auto_create_event_from_approved_proposal',
        module: 'Event Management',
        details: {
          'proposalId': proposalId,
          'eventTitle': title,
          'orgId': orgId,
        },
      );
      
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Event automatically added to calendar!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error creating event from proposal: $e');
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Proposal approved but event creation failed: $e'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _addOneHourToTimeString(String timeStr) {
    try {
      final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false).firstMatch(timeStr);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final isPM = match.group(3)!.toUpperCase() == 'PM';
        
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        
        final dateTime = DateTime(2024, 1, 1, hour, minute);
        final newDateTime = dateTime.add(const Duration(hours: 1));
        
        int newHour = newDateTime.hour;
        final newMinute = newDateTime.minute;
        final newIsPM = newHour >= 12;
        if (newHour > 12) newHour -= 12;
        if (newHour == 0) newHour = 12;
        
        return '$newHour:${newMinute.toString().padLeft(2, '0')} ${newIsPM ? 'PM' : 'AM'}';
      }
    } catch (e) {}
    return '10:00 AM';
  }

  Future<void> _setStatus(String docId, String title, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('event_proposals').doc(docId).update({
        'status':     newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      await activity_log.ActivityLogger.log(
        action: '${newStatus.toUpperCase()} proposal: $title',
        module: 'Event Management',
        severity: newStatus == 'rejected' ? 'warning' : 'info',
        details: {'proposalId': docId},
      );
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Proposal ${newStatus[0].toUpperCase()}${newStatus.substring(1)}'),
          backgroundColor: newStatus == 'approved'
              ? const Color(0xFF059669)
              : newStatus == 'rejected'
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF6B7280),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showProposalDetailDialog(String docId, Map<String, dynamic> data) {
    final status         = (data['status'] ?? 'pending') as String;
    final hasAttachment  = data['attachmentBase64'] != null &&
        data['attachmentBase64'].toString().isNotEmpty;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 540,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        data['title'] ?? 'Event Proposal',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        data['orgName'] ?? '',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: Colors.white.withOpacity(0.7)),
                      ),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Proposal Details', icon: Icons.info_outline_rounded),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: _detailItem('Status',
                              status[0].toUpperCase() + status.substring(1),
                              Icons.circle_outlined,
                              valueColor: status == 'approved'
                                  ? const Color(0xFF059669)
                                  : status == 'rejected'
                                      ? const Color(0xFFDC2626)
                                      : status == 'archived'
                                          ? const Color(0xFF6B7280)
                                          : const Color(0xFFFB923C)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _detailItem('Category', data['category'] ?? '—',
                              Icons.category_outlined),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: _detailItem('Proposed Date', _formatDate(data['date']),
                              Icons.calendar_today_outlined),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _detailItem('Time', data['time'] ?? '—', Icons.access_time_rounded),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: _detailItem('Location', data['location'] ?? '—',
                              Icons.location_on_outlined),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _detailItem('Audience', data['audience'] ?? '—',
                              Icons.people_outline_rounded),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _detailItem('Description',
                          data['description'] ?? 'No description provided.',
                          Icons.description_outlined),
                      const SizedBox(height: 14),
                      _detailItem('Submitted By', data['submittedByEmail'] ?? '—',
                          Icons.person_outline_rounded),
                      const SizedBox(height: 14),
                      _detailItem('Issues Certificate', 
                          (data['issuesCertificate'] == true) ? 'Yes ✅' : 'No ❌', 
                          Icons.verified_outlined,
                          valueColor: (data['issuesCertificate'] == true) 
                              ? const Color(0xFF059669) 
                              : const Color(0xFF6B7280)),
                      if (data['reviewedAt'] != null) ...[
                        const SizedBox(height: 14),
                        _detailItem('Reviewed', _formatTimestamp(data['reviewedAt']),
                            Icons.rate_review_outlined),
                      ],
                      if (hasAttachment) ...[
                        const SizedBox(height: 20),
                        _sectionLabel('Attachment', icon: Icons.attach_file_rounded),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E6EA)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: UpriseColors.primaryDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.insert_drive_file_rounded,
                                  size: 20, color: UpriseColors.primaryDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  data['attachmentName'] ?? 'Attached File',
                                  style: GoogleFonts.beVietnamPro(
                                      fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                if (data['attachmentSize'] != null)
                                  Text(data['attachmentSize'],
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 11, color: const Color(0xFF9AA5B4))),
                              ]),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _saveAndOpenFile(data),
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: Text('Open',
                                  style: GoogleFonts.beVietnamPro(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: UpriseColors.primaryDark,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // ============ DIALOG FOOTER BUTTONS - CORRECTED LOGIC ============
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                  color: Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(children: [
                  // For PENDING only: Show Approve and Reject buttons
                  if (status == 'pending') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmSetStatus(docId, data['title'] ?? 'this event', 'approved');
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 15),
                        label: Text('Approve',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmSetStatus(docId, data['title'] ?? 'this event', 'rejected');
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 15),
                        label: Text('Reject',
                            style: GoogleFonts.beVietnamPro(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Archive button - visible if not archived
                  if (status != 'archived')
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmSetStatus(docId, data['title'] ?? 'this event', 'archived');
                      },
                      icon: const Icon(Icons.archive_outlined, size: 15),
                      label: Text('Archive',
                          style: GoogleFonts.beVietnamPro(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E6EA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    child: Text('Close',
                        style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: const Color(0xFF9AA5B4)),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
                letterSpacing: 0.4)),
      ]),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: valueColor ?? const Color(0xFF1A202C),
        ),
      ),
    ]);
  }

  Future<void> _saveAndOpenFile(Map<String, dynamic> data) async {
    try {
      Uint8List bytes = Uint8List(0);
      final String fileName = data['attachmentName'] ?? 'document';
      
      final hasBase64 = data['attachmentBase64'] != null && 
                        data['attachmentBase64'].toString().isNotEmpty;
      final hasUrl = data['attachmentUrl'] != null && 
                     data['attachmentUrl'].toString().isNotEmpty;
      
      if (!hasBase64 && !hasUrl) {
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No attachment found'), backgroundColor: UpriseColors.error),
          );
        }
        return;
      }
      
      if (hasBase64) {
        final String base64String = data['attachmentBase64'];
        bytes = base64Decode(base64String);
        print('✅ Loaded from Base64, size: ${bytes.length} bytes');
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
            if (_isMounted) {
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
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Empty attachment'), backgroundColor: UpriseColors.error),
          );
        }
        return;
      }
      
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      final mime = _getMimeTypeFromExtension(ext);
      
      if (mime.startsWith('text/')) {
        final content = utf8.decode(bytes);
        if (_isMounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(fileName),
              content: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: GoogleFonts.beVietnamPro(fontSize: 12),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
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
        if (_isMounted) {
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      fileName,
                      style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(bytes),
                    ),
                  ),
                  ButtonBar(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
                        },
                        child: const Text('Download'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return;
      }
      
      await platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
      
    } catch (e) {
      print('❌ Error opening attachment: $e');
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
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
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv': return 'text/csv';
      default: return 'application/octet-stream';
    }
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'TBD';
    if (dateField is Timestamp) {
      final d = dateField.toDate();
      return '${d.month}/${d.day}/${d.year}';
    }
    return dateField.toString();
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.month}/${d.day}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return ts.toString();
  }
}

class _ConfirmStyle {
  final IconData icon;
  final Color iconBg, iconColor, btnColor;
  final String heading, body, btnLabel;
  const _ConfirmStyle({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.btnColor,
    required this.heading,
    required this.body,
    required this.btnLabel,
  });
}

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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
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
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C))),
          ]),
        ),
      ]),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
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

class _ExportProposalsButton extends StatelessWidget {
  final String statusFilter, searchTerm;
  const _ExportProposalsButton({
    required this.statusFilter,
    required this.searchTerm,
  });

  @override
  Widget build(BuildContext context) {
    return AdminExportButton(onSelected: (choice) => _doExport(context, choice));
  }

  Future<void> _doExport(BuildContext context, String format) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('event_proposals')
          .orderBy('createdAt', descending: true)
          .get();
      var docs = snap.docs;

      if (statusFilter != 'All') {
        docs = docs
            .where((d) => (d.data())['status'] == statusFilter.toLowerCase())
            .toList();
      }
      if (searchTerm.isNotEmpty) {
        docs = docs.where((d) {
          final data = d.data();
          return (data['title']   ?? '').toString().toLowerCase().contains(searchTerm) ||
              (data['orgName'] ?? '').toString().toLowerCase().contains(searchTerm);
        }).toList();
      }

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No data to export.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      String content, fileName;
      final now = DateTime.now().toString().substring(0, 10);

      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln('Organization,Event Title,Category,Date,Status,Description');
        for (final doc in docs) {
          final d = doc.data();
          String esc(String s) => '"${s.replaceAll('"', '""')}"';
          buf.writeln([
            esc(d['orgName']     ?? ''),
            esc(d['title']       ?? ''),
            esc(d['category']    ?? ''),
            esc(_fmtDate(d['date'])),
            esc(d['status']      ?? ''),
            esc(d['description'] ?? ''),
          ].join(','));
        }
        content  = buf.toString();
        fileName = 'event_proposals_$now.csv';
        await AdminExportUtil.saveText(
          content,
          fileName,
          mimeType: 'text/csv',
        );
      } else if (format == 'pdf') {
        final rows = docs.map((doc) {
          final d = doc.data();
          return [
            d['orgName']     ?? '',
            d['title']       ?? '',
            d['category']    ?? '',
            _fmtDate(d['date']),
            d['status']      ?? '',
            d['description'] ?? '',
          ].map((value) => value.toString()).toList();
        }).toList();

        final pdfBytes = await AdminExportPdf.generateTablePdf(
          title: 'Event Proposals Report',
          headers: const ['Organization', 'Event Title', 'Category', 'Date', 'Status', 'Description'],
          rows: rows,
        );
        await AdminExportUtil.saveBytes(
          pdfBytes,
          'event_proposals_$now.pdf',
          mimeType: 'application/pdf',
        );
      } else {
        throw UnsupportedError('Unsupported export format: $format');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: UpriseColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _fmtDate(dynamic d) {
    if (d == null) return 'TBD';
    if (d is Timestamp) {
      final dt = d.toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    return d.toString();
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon,
              size: 16,
              color: onTap == null
                  ? const Color(0xFFD1D5DB)
                  : (color ?? const Color(0xFF64748B))),
        ),
      ),
    );
  }
}

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
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 20,
            color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
      ),
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$page',
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}