import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import 'package:intl/intl.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../theme/app_theme.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (mirrors student_accounts.dart / org_management.dart)
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
// Shared small widgets
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
  const styles = {
    'approved': (Color(0xFFECFDF5), Color(0xFF059669), 'APPROVED'),
    'pending':  (Color(0xFFFFFBEB), Color(0xFFD97706), 'PENDING'),
    'rejected': (Color(0xFFFEF2F2), Color(0xFFDC2626), 'REJECTED'),
  };
  final s     = styles[status.toLowerCase()];
  final bg    = s?.$1 ?? const Color(0xFFF3F4F6);
  final fg    = s?.$2 ?? const Color(0xFF6B7280);
  final label = s?.$3 ?? status.toUpperCase();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Text(
      label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: fg,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class ExternalRequest {
  final String   id;
  final String   userId;
  final String   userName;
  final String   email;
  final String   university;
  final String   status;
  final DateTime requestDate;
  final String   purpose;

  const ExternalRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.university,
    required this.status,
    required this.requestDate,
    required this.purpose,
  });

  factory ExternalRequest.fromFirestore(
      String id, Map<String, dynamic> d) {
    return ExternalRequest(
      id:          id,
      userId:      d['userId']      ?? '',
      userName:    d['userName']    ?? '',
      email:       d['email']       ?? '',
      university:  d['university']  ?? '',
      status:      d['status']      ?? 'pending',
      requestDate: (d['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      purpose:     d['purpose']     ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class ExternalAccount extends StatefulWidget {
  const ExternalAccount({super.key});

  @override
  _ExternalAccountState createState() => _ExternalAccountState();
}

class _ExternalAccountState extends State<ExternalAccount> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  int    _currentPage  = 1;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────
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

  // ── Stats row ──────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('external_requests')
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            total++;
            final s = (doc.data() as Map)['status'] ?? 'pending';
            if (s == 'pending')  pending++;
            if (s == 'approved') approved++;
            if (s == 'rejected') rejected++;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(
              label: 'Total Requests',
              value: '$total',
              icon:  Icons.people_rounded,
              color: UpriseColors.primaryDark,
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Approved',
              value: '$approved',
              icon:  Icons.check_circle_rounded,
              color: const Color(0xFF059669),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Pending',
              value: '$pending',
              icon:  Icons.pending_rounded,
              color: const Color(0xFFD97706),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Rejected',
              value: '$rejected',
              icon:  Icons.cancel_rounded,
              color: const Color(0xFFDC2626),
            ),
          ]),
        );
      },
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────
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
                hintText: 'Search by name, email, or university…',
                hintStyle: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E6EA))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E6EA))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: UpriseColors.primaryDark, width: 1.5)),
              ),
              onChanged: (_) => setState(() => _currentPage = 1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _FilterDropdown(
          value: _statusFilter,
          items: const ['All', 'Pending', 'Approved', 'Rejected'],
          onChanged: (v) => setState(() {
            _statusFilter = v!;
            _currentPage  = 1;
          }),
        ),
        const SizedBox(width: 10),
        _ExportButton(
          statusFilter: _statusFilter,
          searchTerm:   _searchController.text.trim(),
        ),
      ]),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('external_requests')
          .orderBy('requestDate', descending: true)
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
            return (data['userName']   ?? '').toString().toLowerCase().contains(term) ||
                   (data['email']      ?? '').toString().toLowerCase().contains(term) ||
                   (data['university'] ?? '').toString().toLowerCase().contains(term);
          }).toList();
        }
        if (_statusFilter != 'All') {
          docs = docs
              .where((d) =>
                  (d.data() as Map)['status'] ==
                  _statusFilter.toLowerCase())
              .toList();
        }

        final totalPages =
            docs.isEmpty ? 1 : (docs.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start    = (safePage - 1) * _pageSize;
        final end      = (start + _pageSize).clamp(0, docs.length);
        final pageDocs = docs.isEmpty
            ? <QueryDocumentSnapshot>[]
            : docs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
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
                        final data =
                            pageDocs[i].data() as Map<String, dynamic>;
                        final req = ExternalRequest.fromFirestore(
                            pageDocs[i].id, data);
                        return _buildRow(
                            req: req, isLast: i == pageDocs.length - 1);
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: _headerCell('FULL NAME')),
        Expanded(flex: 3, child: _headerCell('EMAIL')),
        Expanded(flex: 2, child: _headerCell('UNIVERSITY / ORG')),
        Expanded(flex: 2, child: _headerCell('REQUEST DATE')),
        Expanded(flex: 1, child: _headerCell('STATUS')),
        Expanded(
          flex: 2,
          child: Align(
              alignment: Alignment.centerRight,
              child: _headerCell('ACTIONS')),
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

  Widget _buildRow(
      {required ExternalRequest req, required bool isLast}) {
    final formattedDate =
        DateFormat('MMM dd, yyyy').format(req.requestDate);
    final parts    = req.userName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (req.userName.isNotEmpty
            ? req.userName[0].toUpperCase()
            : '?');

    return InkWell(
      hoverColor: const Color(0xFFF8F9FB),
      onTap: () => _showDetails(req),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(children: [
          // Full name with avatar
          Expanded(
            flex: 3,
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      UpriseColors.primaryDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  req.userName.isNotEmpty ? req.userName : '—',
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
          // Email
          Expanded(
            flex: 3,
            child: Text(
              req.email.isNotEmpty ? req.email : '—',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: const Color(0xFF374151)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // University
          Expanded(
            flex: 2,
            child: req.university.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: UpriseColors.primaryDark
                          .withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      req.university,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: UpriseColors.primaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text('—',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: const Color(0xFF9AA5B4))),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              formattedDate,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          // Status
          Expanded(flex: 1, child: _statusBadge(req.status)),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View Details',
                  onTap: () => _showDetails(req),
                ),
                if (req.status == 'pending') ...[
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.check_circle_outline,
                    tooltip: 'Approve',
                    color: const Color(0xFF059669),
                    onTap: () =>
                        _setStatus(req.id, 'approved', userName: req.userName),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.cancel_outlined,
                    tooltip: 'Reject',
                    color: const Color(0xFFDC2626),
                    onTap: () =>
                        _setStatus(req.id, 'rejected', userName: req.userName),
                  ),
                ],
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  color: const Color(0xFFDC2626),
                  onTap: () => _confirmDelete(req),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_off_rounded,
                size: 40, color: Color(0xFF9AA5B4)),
          ),
          const SizedBox(height: 16),
          Text('No external requests found',
              style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              )),
          const SizedBox(height: 6),
          Text('Try adjusting your filters.',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildFooter(
      int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage =
        (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage =
        (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages =
        List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border:
            Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total requests',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: const Color(0xFF64748B)),
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
                    style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFF64748B),
                        fontSize: 12)),
              ),
              _PageNumButton(
                page: totalPages,
                isActive: _currentPage == totalPages,
                onTap: () =>
                    setState(() => _currentPage = totalPages),
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

  // ── Actions ────────────────────────────────────────────────────────

  Future<void> _setStatus(
    String docId,
    String newStatus, {
    required String userName,
  }) async {
    await FirebaseFirestore.instance
        .collection('external_requests')
        .doc(docId)
        .update({'status': newStatus});

    await activity_log.ActivityLogger.log(
      action: '${newStatus.toUpperCase()} external request for $userName',
      module: 'External Account',
      severity: newStatus == 'rejected' ? 'warning' : 'info',
      details: {'requestId': docId},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Request ${newStatus[0].toUpperCase()}${newStatus.substring(1)}'),
        backgroundColor: newStatus == 'approved'
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  // ── View Dialog ────────────────────────────────────────────────────
  void _showDetails(ExternalRequest req) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.userName.isNotEmpty
                              ? req.userName
                              : 'External Request',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          req.email,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color:
                                Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Status + date strip
                    Row(children: [
                      _statusBadge(req.status),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_outlined,
                          size: 13,
                          color: const Color(0xFF9AA5B4)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy – hh:mm a')
                            .format(req.requestDate),
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: const Color(0xFF64748B)),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _sectionLabel('Account Information',
                        icon: Icons.info_outline_rounded),
                    _infoGrid([
                      ('Full Name',
                          req.userName.isNotEmpty
                              ? req.userName
                              : '—'),
                      ('Email',
                          req.email.isNotEmpty
                              ? req.email
                              : '—'),
                      ('University / Organization',
                          req.university.isNotEmpty
                              ? req.university
                              : '—'),
                      ('User ID',
                          req.userId.isNotEmpty
                              ? req.userId
                              : '—'),
                    ]),
                    if (req.purpose.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel('Purpose',
                          icon: Icons.notes_rounded),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFE2E6EA)),
                        ),
                        child: Text(
                          req.purpose,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              color: const Color(0xFF374151),
                              height: 1.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Footer actions
              Container(
                padding:
                    const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(children: [
                  if (req.status == 'pending') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _setStatus(req.id, 'rejected',
                              userName: req.userName);
                        },
                        icon: const Icon(
                            Icons.cancel_rounded, size: 15),
                        label: Text('Reject',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _setStatus(req.id, 'approved',
                              userName: req.userName);
                        },
                        icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 15),
                        label: Text('Approve',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              UpriseColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                        child: Text('Close',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoGrid(List<(String, String)> items) {
    return Wrap(
      spacing: 0,
      runSpacing: 12,
      children: items
          .map((item) => SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4)),
                    const SizedBox(height: 3),
                    Text(item.$2,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A202C))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Delete confirm dialog ──────────────────────────────────────────
  void _confirmDelete(ExternalRequest req) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 20),
                ),
                const SizedBox(width: 14),
                Text('Delete Request',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    )),
              ]),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete the request from "${req.userName}"? This action cannot be undone.',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color:
                                const Color(0xFF374151))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await FirebaseFirestore.instance
                            .collection('external_requests')
                            .doc(req.id)
                            .delete();
                        await activity_log
                            .ActivityLogger.log(
                          action:
                              'Deleted external request for ${req.userName}',
                          module: 'External Account',
                          severity: 'warning',
                          details: {'requestId': req.id},
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: const Text(
                                'Request deleted.'),
                            backgroundColor:
                                UpriseColors.primaryDark,
                            behavior:
                                SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        8)),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor:
                                UpriseColors.error,
                          ));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11),
                    ),
                    child: Text('Delete',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets (mirrors student_accounts.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final Color    color;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
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

  const _FilterDropdown({
    required this.value,
    required this.items,
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
          style: GoogleFonts.beVietnamPro(
              fontSize: 13, color: const Color(0xFF374151)),
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String statusFilter, searchTerm;
  const _ExportButton({
    required this.statusFilter,
    required this.searchTerm,
  });

  @override
  Widget build(BuildContext context) {
    return AdminExportButton(onSelected: (choice) => _doExport(context, choice));
  }

  Future<void> _doExport(
      BuildContext context, String format) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('external_requests')
          .orderBy('requestDate', descending: true)
          .get();
      var docs = snap.docs;
      if (statusFilter != 'All') {
        docs = docs
            .where((d) =>
                d.data()['status'] == statusFilter.toLowerCase())
            .toList();
      }
      if (searchTerm.isNotEmpty) {
        docs = docs.where((d) {
          final data = d.data();
          return (data['userName']   ?? '').toString().toLowerCase().contains(searchTerm) ||
                 (data['email']      ?? '').toString().toLowerCase().contains(searchTerm) ||
                 (data['university'] ?? '').toString().toLowerCase().contains(searchTerm);
        }).toList();
      }

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data to export.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      String content, fileName;
      final now = DateTime.now().toString().substring(0, 10);

      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln('Name,Email,University,Purpose,Status,Request Date');
        for (final doc in docs) {
          final d = doc.data();
          String esc(String s) => '"${s.replaceAll('"', '""')}"';
          final date = (d['requestDate'] as Timestamp?)
                  ?.toDate()
                  .toString()
                  .substring(0, 10) ??
              '';
          buf.writeln([
            esc(d['userName']   ?? ''),
            esc(d['email']      ?? ''),
            esc(d['university'] ?? ''),
            esc(d['purpose']    ?? ''),
            esc(d['status']     ?? ''),
            esc(date),
          ].join(','));
        }
        content  = buf.toString();
        fileName = 'external_requests_$now.csv';
        await AdminExportUtil.saveText(
          content,
          fileName,
          mimeType: 'text/csv',
        );
      } else if (format == 'pdf') {
        final rows = docs.map((doc) {
          final d = doc.data();
          final date = (d['requestDate'] as Timestamp?)
                  ?.toDate()
                  .toString()
                  .substring(0, 10) ??
              '';
          return [
            d['userName']   ?? '',
            d['email']      ?? '',
            d['university'] ?? '',
            d['purpose']    ?? '',
            d['status']     ?? '',
            date,
          ].map((value) => value.toString()).toList();
        }).toList();

        final pdfBytes = await AdminExportPdf.generateTablePdf(
          title: 'External Requests Report',
          headers: const ['Name', 'Email', 'University', 'Purpose', 'Status', 'Request Date'],
          rows: rows,
        );
        await AdminExportUtil.saveBytes(
          pdfBytes,
          'external_requests_$now.pdf',
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData      icon;
  final String        tooltip;
  final VoidCallback? onTap;
  final Color?        color;
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
  final IconData     icon;
  final bool         enabled;
  final VoidCallback onTap;
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 20,
            color: enabled
                ? const Color(0xFF374151)
                : const Color(0xFFD1D5DB)),
      ),
    );
  }
}

class _PageNumButton extends StatelessWidget {
  final int          page;
  final bool         isActive;
  final VoidCallback onTap;
  const _PageNumButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

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
          color: isActive
              ? UpriseColors.primaryDark
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$page',
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight:
                isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive
                ? Colors.white
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}