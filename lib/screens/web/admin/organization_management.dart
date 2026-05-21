import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';

// ============ ACTIVITY LOGGER ============
class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email ?? 'Unknown User';
    await _firestore.collection('activity_logs').add({
      'user': userName,
      'action': action,
      'module': module,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '',
      'details': details,
    });
  }
}

// ============ DATA MODELS ============
class Officer {
  final String id;
  final String name;
  final String position;
  final String email;
  Officer({required this.id, required this.name, required this.position, required this.email});
  factory Officer.fromMap(Map<String, dynamic> map) => Officer(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        position: map['position'] ?? '',
        email: map['email'] ?? '',
      );
}

/// Represents a faculty adviser attached to an organization
class Adviser {
  final String name;
  final String title;
  final String email;
  final String phone;

  Adviser({
    required this.name,
    required this.title,
    required this.email,
    required this.phone,
  });

  factory Adviser.fromMap(Map<String, dynamic> map) => Adviser(
        name: map['name'] ?? '',
        title: map['title'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'title': title,
        'email': email,
        'phone': phone,
      };

  Adviser copyWith({String? name, String? title, String? email, String? phone}) => Adviser(
        name: name ?? this.name,
        title: title ?? this.title,
        email: email ?? this.email,
        phone: phone ?? this.phone,
      );
}

class Organization {
  final String id;
  final String name;
  final String shortName;
  final String type;
  final String description;
  // Legacy single-adviser fields (kept for backward compat display)
  final String adviserName;
  final String adviserTitle;
  final String adviserEmail;
  final String adviserPhone;
  final String orgEmail;
  final String logoUrl;
  final String status;
  final DateTime? createdAt;
  final List<String> categories;
  final List<Officer> officers;
  // Multi-adviser list (primary data source going forward)
  final List<Adviser> advisers;

  Organization({
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.description,
    required this.adviserName,
    required this.adviserTitle,
    required this.adviserEmail,
    required this.adviserPhone,
    this.orgEmail = '',
    required this.logoUrl,
    required this.status,
    this.createdAt,
    required this.categories,
    required this.officers,
    this.advisers = const [],
  });
}

// ============ SHARED DESIGN TOKENS ============
class _DS {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static final modalShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.18),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  static InputDecoration inputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: UpriseColors.darkGray) : null,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.mediumGray),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.mediumGray, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1),
      ),
    );
  }
}

// ============ SHARED WIDGETS ============

Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
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
        Expanded(child: Divider(color: UpriseColors.mediumGray, thickness: 1)),
      ],
    ),
  );
}

Widget _fieldGroup(List<Widget> fields) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      border: Border.all(color: const Color(0xFFE8ECF0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields
          .expand((f) => [f, const SizedBox(height: 12)])
          .toList()
        ..removeLast(),
    ),
  );
}

Widget _statusBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'active': _BadgeStyle(const Color(0xFFECFDF5), const Color(0xFF059669), 'ACTIVE'),
    'suspended': _BadgeStyle(const Color(0xFFFFFBEB), const Color(0xFFD97706), 'SUSPENDED'),
    'archived': _BadgeStyle(const Color(0xFFF3F4F6), const Color(0xFF6B7280), 'ARCHIVED'),
  };
  final s = styles[status.toLowerCase()] ?? styles['archived']!;
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

// ============ MAIN ORGANIZATION MANAGEMENT WIDGET ============
class OrganizationManagement extends StatefulWidget {
  const OrganizationManagement({super.key});

  @override
  _OrganizationManagementState createState() => _OrganizationManagementState();
}

class _OrganizationManagementState extends State<OrganizationManagement> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  String _typeFilter = 'All Types';
  int _currentPage = 1;
  static const int _pageSize = 10;

  final List<String> _orgTypes = [
    'All Types',
    'Academic Organization',
    'Student Government',
    'Special Interest Group',
    'Cultural Organization',
    'Sports Organization',
  ];

  Organization? _selectedOrganization;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: _selectedOrganization != null
          ? OrganizationDetailPage(
              organization: _selectedOrganization!,
              onBack: () => setState(() => _selectedOrganization = null),
            )
          : _buildOrganizationList(),
    );
  }

  Widget _buildOrganizationList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stats row replaces the old header ──
        _buildStatsRow(),
        _buildToolbar(),
        const SizedBox(height: 16),
        Expanded(child: _buildTable()),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Stats at the very top (no separate header) ──
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('organizations').snapshots(),
      builder: (context, snapshot) {
        int total = 0, active = 0, suspended = 0, archived = 0;
        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final status = (doc.data() as Map)['status'] ?? 'active';
            switch (status) {
              case 'active':
                active++;
                break;
              case 'suspended':
                suspended++;
                break;
              case 'archived':
                archived++;
                break;
            }
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(label: 'Total Organizations', value: '$total', icon: Icons.business_center_rounded, color: UpriseColors.primaryDark),
            const SizedBox(width: 14),
            _StatCard(label: 'Active', value: '$active', icon: Icons.check_circle_rounded, color: const Color(0xFF059669)),
            const SizedBox(width: 14),
            _StatCard(label: 'Suspended', value: '$suspended', icon: Icons.pause_circle_rounded, color: const Color(0xFFD97706)),
            const SizedBox(width: 14),
            _StatCard(label: 'Archived', value: '$archived', icon: Icons.archive_rounded, color: const Color(0xFF6B7280)),
          ]),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.beVietnamPro(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search organization or adviser…',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() => _currentPage = 1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _statusFilter,
            items: ['All', 'Active', 'Suspended', 'Archived'],
            hint: 'Status',
            icon: Icons.tune_rounded,
            onChanged: (v) => setState(() {
              _statusFilter = v!;
              _currentPage = 1;
            }),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _typeFilter,
            items: _orgTypes,
            hint: 'Type',
            icon: Icons.category_rounded,
            onChanged: (v) => setState(() {
              _typeFilter = v!;
              _currentPage = 1;
            }),
          ),
          const SizedBox(width: 10),
          _ExportButton(
            statusFilter: _statusFilter,
            typeFilter: _typeFilter,
            searchTerm: _searchController.text.trim(),
          ),
          const SizedBox(width: 10),
          _PrimaryButton(
            label: 'Create Organization',
            icon: Icons.add_rounded,
            onPressed: _showCreateOrganizationDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('organizations').orderBy('createdAt', descending: true).snapshots(),
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
        if (_typeFilter != 'All Types') {
          docs = docs.where((d) => (d.data() as Map)['type'] == _typeFilter).toList();
        }
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            final adviserMatch = (data['adviserName'] ?? '').toString().toLowerCase().contains(term);
            // Also search in multi-adviser list
            final advisers = (data['advisers'] as List?) ?? [];
            final multiAdviserMatch = advisers.any((a) =>
                (a['name'] ?? '').toString().toLowerCase().contains(term));
            return (data['name'] ?? '').toString().toLowerCase().contains(term) ||
                adviserMatch ||
                multiAdviserMatch;
          }).toList();
        }

        final totalPages = docs.isEmpty ? 1 : (docs.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, docs.length);
        final pageDocs = docs.isEmpty ? <QueryDocumentSnapshot>[] : docs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(
            children: [
              // ── Table toolbar row with "Create Organization" button ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
                ),
                child: Row(children: [
                  Expanded(flex: 3, child: _headerCell('ORGANIZATION')),
                  Expanded(flex: 2, child: _headerCell('ADVISERS')),
                  Expanded(flex: 1, child: _headerCell('TYPE')),
                  Expanded(flex: 1, child: _headerCell('STATUS')),
                  Expanded(flex: 1, child: _headerCell('CREATED')),
                  Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: _headerCell('ACTIONS'))),
                ]),
              ),
              // Table body
              Expanded(
                child: docs.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        itemCount: pageDocs.length,
                        itemBuilder: (_, i) {
                          final data = pageDocs[i].data() as Map<String, dynamic>;
                          final org = _mapToOrg(pageDocs[i].id, data);
                          return _buildOrganizationRow(org, i == pageDocs.length - 1);
                        },
                      ),
              ),
              // Footer
              _buildFooter(docs.length, totalPages, start, end),
            ],
          ),
        );
      },
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

  Widget _emptyState() {
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
            child: Icon(Icons.corporate_fare_rounded, size: 40, color: UpriseColors.mediumGray),
          ),
          const SizedBox(height: 16),
          Text('No organizations found',
              style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text('Try adjusting your filters or create a new organization.',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
        ],
      ),
    );
  }

  Organization _mapToOrg(String id, Map<String, dynamic> data) {
    // Parse multi-adviser list; fall back to legacy single adviser
    final rawAdvisers = data['advisers'] as List?;
    List<Adviser> advisers = rawAdvisers != null
        ? rawAdvisers.map((e) => Adviser.fromMap(e as Map<String, dynamic>)).toList()
        : [];

    // If no multi-adviser data but legacy fields exist, synthesise one
    if (advisers.isEmpty && (data['adviserName'] ?? '').toString().isNotEmpty) {
      advisers = [
        Adviser(
          name: data['adviserName'] ?? '',
          title: data['adviserTitle'] ?? '',
          email: data['adviserEmail'] ?? '',
          phone: data['adviserPhone'] ?? '',
        )
      ];
    }

    return Organization(
      id: id,
      name: data['name'] ?? '',
      shortName: data['shortName'] ?? '',
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      adviserName: advisers.isNotEmpty ? advisers.first.name : (data['adviserName'] ?? 'No Adviser'),
      adviserTitle: advisers.isNotEmpty ? advisers.first.title : (data['adviserTitle'] ?? ''),
      adviserEmail: advisers.isNotEmpty ? advisers.first.email : (data['adviserEmail'] ?? ''),
      adviserPhone: advisers.isNotEmpty ? advisers.first.phone : (data['adviserPhone'] ?? ''),
      orgEmail: data['orgEmail'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      categories: List<String>.from(data['categories'] ?? []),
      officers: (data['officers'] as List?)?.map((e) => Officer.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      advisers: advisers,
    );
  }

  Widget _buildOrganizationRow(Organization org, bool isLast) {
    // Build adviser summary string
    final adviserSummary = org.advisers.isEmpty
        ? 'No Adviser'
        : org.advisers.map((a) => a.name).join(', ');
    final adviserEmailSummary = org.advisers.isEmpty
        ? ''
        : org.advisers.first.email +
            (org.advisers.length > 1 ? ' +${org.advisers.length - 1} more' : '');

    return InkWell(
      onTap: () => setState(() => _selectedOrganization = org),
      hoverColor: const Color(0xFFF8F9FB),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // Organization column
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _OrgAvatar(logoUrl: org.logoUrl, name: org.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: GoogleFonts.beVietnamPro(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: const Color(0xFF1A202C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (org.shortName.isNotEmpty)
                          Text(
                            org.shortName,
                            style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Advisers column
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adviserSummary,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (adviserEmailSummary.isNotEmpty)
                    Text(
                      adviserEmailSummary,
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Type column
            Expanded(
              flex: 1,
              child: Text(
                org.type,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status column
            Expanded(flex: 1, child: _statusBadge(org.status)),
            // Date column
            Expanded(
              flex: 1,
              child: Text(
                org.createdAt != null ? _formatDate(org.createdAt!) : '—',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
              ),
            ),
            // Actions column
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionIconButton(
                    icon: Icons.open_in_new_rounded,
                    tooltip: 'View Details',
                    onTap: () => setState(() => _selectedOrganization = org),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.edit_rounded,
                    tooltip: 'Edit',
                    onTap: () => _showEditOrganizationDialog(org),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: org.status == 'archived' ? Icons.restore_rounded : Icons.archive_rounded,
                    tooltip: org.status == 'archived' ? 'Restore' : 'Archive',
                    onTap: () => _toggleArchiveOrganization(org),
                    color: org.status == 'archived' ? const Color(0xFF059669) : const Color(0xFF9AA5B4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total organizations',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
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
                child: Text('…', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 12)),
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

  // ── Dialogs ──

  void _showCreateOrganizationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => CreateOrganizationDialog(onCreated: () => setState(() {})),
    );
  }

  void _showEditOrganizationDialog(Organization org) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => EditOrganizationDialog(organization: org, onUpdated: () => setState(() {})),
    );
  }

  Future<void> _toggleArchiveOrganization(Organization org) async {
    final isArchived = org.status == 'archived';
    final newStatus = isArchived ? 'active' : 'archived';

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _ConfirmDialog(
        title: isArchived ? 'Restore Organization' : 'Archive Organization',
        message: 'Are you sure you want to ${isArchived ? 'restore' : 'archive'} "${org.name}"?',
        confirmLabel: isArchived ? 'Restore' : 'Archive',
        confirmColor: isArchived ? const Color(0xFF059669) : UpriseColors.primaryDark,
        icon: isArchived ? Icons.restore_rounded : Icons.archive_rounded,
        onConfirm: () async {
          await FirebaseFirestore.instance.collection('organizations').doc(org.id).update({'status': newStatus});
          await ActivityLogger.log(
            action: '${isArchived ? 'Restored' : 'Archived'} organization: ${org.name}',
            module: 'Organizations',
          );
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${org.name} has been ${isArchived ? 'restored' : 'archived'}'),
              backgroundColor: isArchived ? const Color(0xFF059669) : UpriseColors.primaryDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) => DateFormat('MMM d, yyyy').format(d);
}

// ============ SMALL REUSABLE WIDGETS ============

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
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          children: [
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
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9AA5B4)),
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

class _ExportButton extends StatelessWidget {
  final String statusFilter, typeFilter, searchTerm;
  const _ExportButton({required this.statusFilter, required this.typeFilter, required this.searchTerm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: PopupMenuButton<String>(
        onSelected: (choice) => _doExport(context, choice),
        itemBuilder: (_) => [
          _exportMenuItem('csv', Icons.table_chart_rounded, 'Export as CSV'),
          _exportMenuItem('json', Icons.data_object_rounded, 'Export as JSON'),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.download_rounded, size: 16, color: Color(0xFF374151)),
              const SizedBox(width: 6),
              Text('Export', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9AA5B4)),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _exportMenuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13)),
      ]),
    );
  }

  Future<void> _doExport(BuildContext context, String format) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .orderBy('createdAt', descending: true)
          .get();
      var docs = snapshot.docs;

      if (statusFilter != 'All') {
        docs = docs.where((d) => (d.data())['status'] == statusFilter.toLowerCase()).toList();
      }
      if (typeFilter != 'All Types') {
        docs = docs.where((d) => (d.data())['type'] == typeFilter).toList();
      }
      if (searchTerm.isNotEmpty) {
        docs = docs.where((d) {
          final data = d.data();
          return (data['name'] ?? '').toString().toLowerCase().contains(searchTerm) ||
              (data['adviserName'] ?? '').toString().toLowerCase().contains(searchTerm);
        }).toList();
      }

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No data to export.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        return;
      }

      String content;
      String fileName;
      final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (format == 'csv') {
        final buffer = StringBuffer();
        buffer.writeln('Organization Name,Short Name,Type,Status,Adviser(s),Org Email,Description,Date Created');
        for (final doc in docs) {
          final d = doc.data();
          final date = (d['createdAt'] as Timestamp?)?.toDate();
          final dateStr = date != null ? DateFormat('yyyy-MM-dd').format(date) : '';
          String csvEscape(String s) => '"${s.replaceAll('"', '""')}"';
          final advisers = (d['advisers'] as List?)
                  ?.map((a) => (a['name'] ?? '').toString())
                  .join('; ') ??
              (d['adviserName'] ?? '');
          buffer.writeln([
            csvEscape(d['name'] ?? ''),
            csvEscape(d['shortName'] ?? ''),
            csvEscape(d['type'] ?? ''),
            csvEscape(d['status'] ?? ''),
            csvEscape(advisers),
            csvEscape(d['orgEmail'] ?? ''),
            csvEscape(d['description'] ?? ''),
            csvEscape(dateStr),
          ].join(','));
        }
        content = buffer.toString();
        fileName = 'organizations_$now.csv';
      } else {
        final list = docs.map((doc) {
          final d = doc.data();
          final date = (d['createdAt'] as Timestamp?)?.toDate();
          return {
            'id': doc.id,
            'name': d['name'] ?? '',
            'shortName': d['shortName'] ?? '',
            'type': d['type'] ?? '',
            'status': d['status'] ?? '',
            'advisers': d['advisers'] ?? [],
            'orgEmail': d['orgEmail'] ?? '',
            'description': d['description'] ?? '',
            'createdAt': date?.toIso8601String() ?? '',
          };
        }).toList();
        content = const JsonEncoder.withIndent('  ').convert(list);
        fileName = 'organizations_$now.json';
      }

      if (kIsWeb) {
        // Web: share as text (no File system access)
        await Share.share(content, subject: fileName);
      } else {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(content);
        await Share.shareXFiles([XFile(file.path)], subject: fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: UpriseColors.primaryDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  final String logoUrl, name;
  const _OrgAvatar({required this.logoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials()),
            )
          : _initials(),
    );
  }

  Widget _initials() {
    final parts = name.split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Center(
      child: Text(initials,
          style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  const _ActionIconButton({required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color ?? const Color(0xFF64748B)),
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
        child: Icon(icon, size: 20, color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
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

// ============ CONFIRM DIALOG ============
class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final Future<void> Function() onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                decoration: BoxDecoration(color: confirmColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: confirmColor, size: 20),
              ),
              const SizedBox(width: 14),
              Text(title, style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
            ]),
            const SizedBox(height: 16),
            Text(message, style: GoogleFonts.beVietnamPro(fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E6EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text(confirmLabel, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ADVISER FORM WIDGET ============
/// Inline form for entering one adviser's details.
class _AdviserForm extends StatelessWidget {
  final Adviser adviser;
  final int index;
  final bool canRemove;
  final ValueChanged<Adviser> onChanged;
  final VoidCallback onRemove;

  const _AdviserForm({
    required this.adviser,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            'Adviser ${index + 1}',
            style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark),
          ),
          if (canRemove)
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: UpriseColors.error),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              initialValue: adviser.name,
              decoration: _DS.inputDecoration('Full Name', hint: 'e.g., Dr. Juan dela Cruz', icon: Icons.badge_outlined),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              onChanged: (v) => onChanged(adviser.copyWith(name: v)),
              validator: (v) => index == 0 && (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: adviser.title,
              decoration: _DS.inputDecoration('Title / Designation', hint: 'e.g., Associate Professor'),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              onChanged: (v) => onChanged(adviser.copyWith(title: v)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              initialValue: adviser.email,
              decoration: _DS.inputDecoration('Email', hint: 'e.g., jdelacruz@university.edu.ph', icon: Icons.email_outlined),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => onChanged(adviser.copyWith(email: v)),
              validator: (v) {
                if (index == 0) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                } else if (v != null && v.trim().isNotEmpty) {
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: adviser.phone,
              decoration: _DS.inputDecoration('Phone Number', hint: 'e.g., +63 912 345 6789', icon: Icons.phone_outlined),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              keyboardType: TextInputType.phone,
              onChanged: (v) => onChanged(adviser.copyWith(phone: v)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ============ CREATE ORGANIZATION DIALOG ============
class CreateOrganizationDialog extends StatefulWidget {
  final VoidCallback onCreated;
  const CreateOrganizationDialog({super.key, required this.onCreated});

  @override
  _CreateOrganizationDialogState createState() => _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<CreateOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  // Step 1 — Basic Info
  final _nameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();
  final _orgEmailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'Academic Organization';
  XFile? _logoXFile; // Use XFile for cross-platform compatibility

  // Step 2 — Advisers (supports multiple)
  List<Adviser> _advisers = [Adviser(name: '', title: '', email: '', phone: '')];

  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _shortNameCtrl, _orgEmailCtrl, _descCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 620,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(children: [
          _buildModalHeader('Create New Organization', Icons.add_business_rounded),
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: _step == 0 ? _buildStep1() : _buildStep2(),
              ),
            ),
          ),
          _buildModalFooter(),
        ]),
      ),
    );
  }

  Widget _buildModalHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Basic Information', 'Faculty Advisers'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isActive = idx == _step;
          final isDone = idx < _step;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isActive || isDone ? UpriseColors.primaryDark : const Color(0xFFE2E6EA),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : Text('${idx + 1}',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.white : const Color(0xFF9AA5B4),
                            )),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? UpriseColors.primaryDark : const Color(0xFF9AA5B4),
                  ),
                ),
                if (idx < steps.length - 1) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Divider(color: isDone ? UpriseColors.primaryDark : const Color(0xFFE2E6EA), thickness: 1.5)),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Organization Logo', icon: Icons.image_rounded),
      Center(
        child: GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E6EA), width: 1.5),
            ),
            child: _logoXFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(_logoXFile!.path, fit: BoxFit.cover),
                  )
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_rounded, size: 32, color: UpriseColors.darkGray),
                    const SizedBox(height: 6),
                    Text('Upload Logo', style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                  ]),
          ),
        ),
      ),
      const SizedBox(height: 24),

      _sectionLabel('Organization Details', icon: Icons.business_rounded),
      _fieldGroup([
        TextFormField(
          controller: _nameCtrl,
          decoration: _DS.inputDecoration('Organization Name', hint: 'e.g., Society of Web Innovators and Tech Specialists'),
          style: GoogleFonts.beVietnamPro(fontSize: 13),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _shortNameCtrl,
              decoration: _DS.inputDecoration('Acronym / Short Name', hint: 'e.g., SWITS'),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _type,
              decoration: _DS.inputDecoration('Organization Type'),
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
              items: ['Academic Organization', 'Student Government', 'Special Interest Group', 'Cultural Organization', 'Sports Organization']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
          ),
        ]),
        TextFormField(
          controller: _orgEmailCtrl,
          decoration: _DS.inputDecoration('Organization Email', hint: 'e.g., swits@university.edu.ph', icon: Icons.email_outlined),
          style: GoogleFonts.beVietnamPro(fontSize: 13),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
            return null;
          },
        ),
        TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: _DS.inputDecoration('Organization Description',
              hint: 'Brief description of the organization\'s goals and activities...'),
          style: GoogleFonts.beVietnamPro(fontSize: 13),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
      ]),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Faculty Advisers', icon: Icons.people_rounded),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          border: Border.all(color: const Color(0xFFBFD7FF)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Each adviser will receive login credentials via email. The first adviser is required.',
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF1D4ED8)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Render adviser forms
      ..._advisers.asMap().entries.map((entry) {
        final idx = entry.key;
        final adviser = entry.value;
        return _AdviserForm(
          adviser: adviser,
          index: idx,
          canRemove: _advisers.length > 1,
          onChanged: (updated) => setState(() => _advisers[idx] = updated),
          onRemove: () => setState(() => _advisers.removeAt(idx)),
        );
      }),

      // "Add another adviser" button — max 2
      if (_advisers.length < 2)
        TextButton.icon(
          onPressed: () => setState(() => _advisers.add(Adviser(name: '', title: '', email: '', phone: ''))),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
          label: Text('Add Another Adviser', style: GoogleFonts.beVietnamPro(fontSize: 13)),
          style: TextButton.styleFrom(foregroundColor: UpriseColors.primaryDark),
        ),
    ]);
  }

  Widget _buildModalFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _step--),
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: Text('Back', style: GoogleFonts.beVietnamPro(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E6EA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              ),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
            ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _onNextOrCreate,
            icon: _isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_step == 0 ? Icons.arrow_forward_rounded : Icons.check_rounded, size: 16),
            label: Text(
              _step == 0 ? 'Continue' : 'Create Organization',
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: UpriseColors.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _onNextOrCreate() {
    if (!_formKey.currentState!.validate()) return;
    if (_step == 0) {
      setState(() => _step = 1);
    } else {
      _createOrganization();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoXFile = picked);
  }

  /// Check if an org with the same name OR short name already exists
  Future<String?> _checkDuplicateOrg(String name, String shortName) async {
    final byNameFuture = FirebaseFirestore.instance
        .collection('organizations')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    final byShortFuture = FirebaseFirestore.instance
        .collection('organizations')
        .where('shortName', isEqualTo: shortName)
        .limit(1)
        .get();

    final results = await Future.wait([byNameFuture, byShortFuture]);
    final byName = results[0];
    final byShort = results[1];

    if (byName.docs.isNotEmpty) return 'An organization named "$name" already exists.';
    if (byShort.docs.isNotEmpty) return 'An organization with acronym "$shortName" already exists.';
    return null;
  }

  Future<bool> _isEmailRegistered(String email) async {
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _generateTemporaryPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return 'UPR-${List.generate(6, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  /// Web-safe logo upload using XFile.readAsBytes()
  Future<String?> _uploadLogo(XFile? xFile, String orgId) async {
    if (xFile == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('organizations/$orgId/logo.png');
      final bytes = await xFile.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Logo upload error: $e');
      return null;
    }
  }

  /// Send login credentials to the organization email address
  Future<bool> _sendCredentialsEmail({
    required String toEmail,
    required String orgName,
    required String recipientName,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': 'service_s3ke8zd',
          'template_id': 'template_t92k1um',
          'user_id': 'tmx47wQJmb1uMNUpr',
          'template_params': {
            'to_email': toEmail,
            'to_name': recipientName,
            'password': password,
            'org_name': orgName,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Organization credentials email sent to $toEmail');
        return true;
      }

      debugPrint('❌ EmailJS error ${response.statusCode}: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Failed to send organization credentials email: $e');
      return false;
    }
  }

  Future<void> _createOrganization() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final orgName = _nameCtrl.text.trim();
    final orgShortName = _shortNameCtrl.text.trim();
    final orgDesc = _descCtrl.text.trim();
    final orgEmail = _orgEmailCtrl.text.trim().toLowerCase();

    // Filter out empty adviser rows (only keep rows with at least a name)
    final validAdvisers = _advisers.where((a) => a.name.trim().isNotEmpty).toList();

    try {
      // ── Duplicate org check ──
      final dupError = await _checkDuplicateOrg(orgName, orgShortName);
      if (dupError != null) {
        _showError(dupError);
        return;
      }

      // ── Org portal login email check ──
      if (orgEmail.isEmpty) {
        _showError('Organization email is required for portal login.');
        return;
      }
      if (await _isEmailRegistered(orgEmail)) {
        _showError('Email "$orgEmail" already has an account in the system.');
        return;
      }

      // ── Create org document first to get the ID ──
      final orgRef = FirebaseFirestore.instance.collection('organizations').doc();
      final orgId = orgRef.id;

      final logoUrl = await _uploadLogo(_logoXFile, orgId);

      final batch = FirebaseFirestore.instance.batch();

      // ── Create Firebase Auth account and user doc for the organization portal ──
      final List<Map<String, dynamic>> adviserMaps = validAdvisers
          .map((a) => {
                'name': a.name,
                'title': a.title,
                'email': a.email.trim().toLowerCase(),
                'phone': a.phone,
              })
          .toList();

      final tempPassword = _generateTemporaryPassword();
      final List<Map<String, String>> createdAccounts = [
        {'email': orgEmail, 'name': orgName, 'password': tempPassword}
      ];

      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('secondaryApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'secondaryApp',
          options: Firebase.app().options,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      UserCredential cred;
      try {
        cred = await secondaryAuth.createUserWithEmailAndPassword(email: orgEmail, password: tempPassword);
      } on FirebaseAuthException catch (e) {
        await secondaryAuth.signOut();
        _showError('Failed to create organization login account: ${e.message}');
        return;
      }

      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(orgName);

      batch.set(FirebaseFirestore.instance.collection('users').doc(uid), {
        'uid': uid,
        'fullName': orgName,
        'name': orgName,
        'email': orgEmail,
        'role': 'org',
        'organizationId': orgId,
        'organizationName': orgName,
        'mustChangePassword': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });

      await secondaryAuth.signOut();

      // ── Set org document ──
      // Primary adviser fields use the first adviser for backwards compat
      final primaryAdviser = validAdvisers.isNotEmpty ? validAdvisers.first : Adviser(name: '', title: '', email: '', phone: '');

      batch.set(orgRef, {
        'id': orgId,
        'name': orgName,
        'shortName': orgShortName,
        'acronym': orgShortName,
        'type': _type,
        'description': orgDesc,
        'orgEmail': orgEmail,
        'logoUrl': logoUrl ?? '',
        // Legacy single-adviser fields (backwards compat)
        'adviserId': '',
        'adviserName': primaryAdviser.name,
        'adviserEmail': primaryAdviser.email.trim().toLowerCase(),
        'adviserTitle': primaryAdviser.title,
        'adviserPhone': primaryAdviser.phone,
        // Multi-adviser list
        'advisers': adviserMaps,
        'categories': [],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByEmail': FirebaseAuth.instance.currentUser?.email,
      });

      await batch.commit();

      // ── Send login credentials asynchronously so org creation returns immediately ──
      final account = createdAccounts.first;
      _sendCredentialsEmail(
        toEmail: account['email']!,
        orgName: orgName,
        recipientName: orgName,
        password: account['password']!,
      ).then((sent) {
        if (!sent) {
          debugPrint('⚠️ Failed to send credentials email to $orgEmail');
        }
      });

      await ActivityLogger.log(action: 'Created new organization: $orgName', module: 'Organizations');

      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organization "$orgName" created! Credentials are being sent to $orgEmail.'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      setState(() => _isLoading = false);
    }
  }
}

// ============ EDIT ORGANIZATION DIALOG ============
class EditOrganizationDialog extends StatefulWidget {
  final Organization organization;
  final VoidCallback onUpdated;
  const EditOrganizationDialog({super.key, required this.organization, required this.onUpdated});

  @override
  _EditOrganizationDialogState createState() => _EditOrganizationDialogState();
}

class _EditOrganizationDialogState extends State<EditOrganizationDialog> {
  late TextEditingController _nameCtrl, _shortCtrl, _orgEmailCtrl, _descCtrl;
  late String _type, _status;
  late List<Adviser> _advisers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    _nameCtrl = TextEditingController(text: org.name);
    _shortCtrl = TextEditingController(text: org.shortName);
    _orgEmailCtrl = TextEditingController(text: org.orgEmail);
    _descCtrl = TextEditingController(text: org.description);
    _type = org.type;
    _status = org.status;
    // Initialise adviser list from org; guarantee at least one entry
    _advisers = org.advisers.isNotEmpty
        ? List<Adviser>.from(org.advisers)
        : [Adviser(name: org.adviserName, title: org.adviserTitle, email: org.adviserEmail, phone: org.adviserPhone)];
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _shortCtrl, _orgEmailCtrl, _descCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 640,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(children: [
          // Header
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
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Edit Organization',
                      style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(widget.organization.name,
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: GlobalKey<FormState>(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Organization info
                  _sectionLabel('Organization Information', icon: Icons.business_rounded),
                  _fieldGroup([
                    TextFormField(
                        controller: _nameCtrl,
                        decoration: _DS.inputDecoration('Organization Name'),
                        style: GoogleFonts.beVietnamPro(fontSize: 13)),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: _shortCtrl,
                              decoration: _DS.inputDecoration('Acronym / Short Name'),
                              style: GoogleFonts.beVietnamPro(fontSize: 13))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _type,
                          decoration: _DS.inputDecoration('Organization Type'),
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                          items: ['Academic Organization', 'Student Government', 'Special Interest Group', 'Cultural Organization', 'Sports Organization']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                    ]),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: _orgEmailCtrl,
                              decoration: _DS.inputDecoration('Organization Email', icon: Icons.email_outlined),
                              style: GoogleFonts.beVietnamPro(fontSize: 13))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: _DS.inputDecoration('Status'),
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                          items: ['active', 'suspended', 'archived']
                              .map((s) => DropdownMenuItem(
                                  value: s, child: Text(s[0].toUpperCase() + s.substring(1))))
                              .toList(),
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      ),
                    ]),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: _DS.inputDecoration('Description'),
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Multi-adviser section
                  _sectionLabel('Faculty Advisers', icon: Icons.people_rounded),
                  ..._advisers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final adviser = entry.value;
                    return _AdviserForm(
                      adviser: adviser,
                      index: idx,
                      canRemove: _advisers.length > 1,
                      onChanged: (updated) => setState(() => _advisers[idx] = updated),
                      onRemove: () => setState(() => _advisers.removeAt(idx)),
                    );
                  }),
                  if (_advisers.length < 2)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _advisers.add(Adviser(name: '', title: '', email: '', phone: ''))),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: Text('Add Another Adviser', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                      style: TextButton.styleFrom(foregroundColor: UpriseColors.primaryDark),
                    ),
                ]),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E6EA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _update,
                icon: _isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text('Save Changes', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _update() async {
    setState(() => _isLoading = true);
    try {
      final validAdvisers = _advisers.where((a) => a.name.trim().isNotEmpty).toList();
      final primaryAdviser = validAdvisers.isNotEmpty ? validAdvisers.first : Adviser(name: '', title: '', email: '', phone: '');

      final adviserMaps = validAdvisers.map((a) => a.toMap()).toList();

      final batch = FirebaseFirestore.instance.batch();

      batch.update(
        FirebaseFirestore.instance.collection('organizations').doc(widget.organization.id),
        {
          'name': _nameCtrl.text.trim(),
          'shortName': _shortCtrl.text.trim(),
          'type': _type,
          'description': _descCtrl.text.trim(),
          'orgEmail': _orgEmailCtrl.text.trim().toLowerCase(),
          'status': _status,
          // Legacy fields
          'adviserName': primaryAdviser.name,
          'adviserTitle': primaryAdviser.title,
          'adviserEmail': primaryAdviser.email,
          'adviserPhone': primaryAdviser.phone,
          // Multi-adviser
          'advisers': adviserMaps,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Update adviser_roles for first adviser
      final existingRoles = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('orgId', isEqualTo: widget.organization.id)
          .get();
      if (existingRoles.docs.isNotEmpty) {
        batch.update(existingRoles.docs.first.reference, {
          'orgName': _nameCtrl.text.trim(),
          'orgAbbrev': _shortCtrl.text.trim(),
          'orgTag': _type,
          'adviserName': primaryAdviser.name,
          'adviserEmail': primaryAdviser.email,
          'adviserPhone': primaryAdviser.phone,
          'adviserRank': primaryAdviser.title,
        });
      }

      await batch.commit();
      await ActivityLogger.log(
          action: 'Updated organization: ${widget.organization.name} → ${_nameCtrl.text.trim()}',
          module: 'Organizations');

      widget.onUpdated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Organization updated successfully.'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: UpriseColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ============ ORGANIZATION DETAIL PAGE ============
class OrganizationDetailPage extends StatefulWidget {
  final Organization organization;
  final VoidCallback onBack;
  const OrganizationDetailPage({super.key, required this.organization, required this.onBack});

  @override
  _OrganizationDetailPageState createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage> {
  @override
  Widget build(BuildContext context) {
    final org = widget.organization;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Breadcrumb / Back
        Row(children: [
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: UpriseColors.darkGray),
                const SizedBox(width: 6),
                Text('Organizations', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.chevron_right_rounded, size: 16, color: UpriseColors.mediumGray),
          ),
          Text(org.shortName.isNotEmpty ? org.shortName : org.name,
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
        ]),
        const SizedBox(height: 20),

        // Hero card
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E6EA)),
                ),
                child: org.logoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(org.logoUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _logoPlaceholder(org.name)))
                    : _logoPlaceholder(org.name),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(org.name,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
                    ),
                    const SizedBox(width: 12),
                    _statusBadge(org.status),
                  ]),
                  const SizedBox(height: 6),
                  if (org.shortName.isNotEmpty)
                    Text(org.shortName,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 15, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
                  const SizedBox(height: 4),
                  Text(org.type, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                  if (org.orgEmail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.email_outlined, size: 14, color: UpriseColors.darkGray),
                      const SizedBox(width: 6),
                      Text(org.orgEmail,
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.primaryDark)),
                    ]),
                  ],
                  if (org.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: UpriseColors.darkGray),
                      const SizedBox(width: 6),
                      Text('Created ${DateFormat('MMMM d, yyyy').format(org.createdAt!)}',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
                    ]),
                  ],
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Description + Advisers
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: _detailCard(
              icon: Icons.info_outline_rounded,
              title: 'About the Organization',
              child: Text(
                org.description.isNotEmpty ? org.description : 'No description provided.',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray, height: 1.6),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Multi-adviser card
          Expanded(
            flex: 2,
            child: _detailCard(
              icon: Icons.people_rounded,
              title: 'Faculty Advisers',
              child: org.advisers.isEmpty
                  ? Text('No adviser assigned.',
                      style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray))
                  : Column(
                      children: org.advisers
                          .map((a) => _adviserTile(a))
                          .expand((w) => [w, const SizedBox(height: 12)])
                          .toList()
                        ..removeLast(),
                    ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _adviserTile(Adviser a) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: UpriseColors.primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
              style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.name,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
            if (a.title.isNotEmpty)
              Text(a.title, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
          ]),
        ),
      ]),
      if (a.email.isNotEmpty) ...[
        const SizedBox(height: 6),
        _adviserDetailRow(Icons.email_outlined, a.email),
      ],
      if (a.phone.isNotEmpty)
        _adviserDetailRow(Icons.phone_outlined, a.phone),
    ]);
  }

  Widget _logoPlaceholder(String name) {
    final parts = name.split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Center(
      child: Text(initials,
          style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
    );
  }

  Widget _detailCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: UpriseColors.primaryDark),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _adviserDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 13, color: UpriseColors.darkGray),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151)))),
      ]),
    );
  }
}
