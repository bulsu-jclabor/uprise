// lib/screens/web/admin/adviser_roles.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'export_util.dart';
import 'export_pdf.dart';
import '../../theme/app_theme.dart';

// Helper for image handling
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
  static const double radiusLg   = 16;
  static const double radiusPill = 100;

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
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
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
          : null,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionDivider(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 15, color: UpriseColors.primaryDark),
        const SizedBox(width: 7),
      ],
      Text(text,
          style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: UpriseColors.primaryDark,
              letterSpacing: 0.3)),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE2E6EA), thickness: 1)),
    ]),
  );
}

class _RankBadge extends StatelessWidget {
  final String rank;
  const _RankBadge(this.rank);

  static Color colorOf(String rank) {
    switch (rank.toLowerCase()) {
      case 'senior':    return const Color(0xFF2563EB);
      case 'junior':    return const Color(0xFFD97706);
      case 'professor': return const Color(0xFF7C3AED);
      default:          return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorOf(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(26),
        borderRadius: BorderRadius.circular(_DS.radiusPill),
      ),
      child: Text(rank,
          style: GoogleFonts.beVietnamPro(
              fontSize: 10, fontWeight: FontWeight.w700, color: c, letterSpacing: 0.5)),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  final String position;
  const _PositionBadge(this.position);

  static Color colorOf(String position) {
    switch (position.toLowerCase()) {
      case 'dean':          return const Color(0xFF7C3AED);
      case 'program chair': return const Color(0xFF2563EB);
      case 'department head': return const Color(0xFFD97706);
      case 'coordinator':   return const Color(0xFF059669);
      default:              return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorOf(position);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(position,
          style: GoogleFonts.beVietnamPro(
              fontSize: 9, fontWeight: FontWeight.w600, color: c, letterSpacing: 0.3)),
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  final String abbrev;
  final String? logoUrl;
  const _OrgAvatar(this.abbrev, {this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        child: _buildImageWidget(logoUrl!, width: 34, height: 34, fit: BoxFit.cover),
      );
    }
    final label = abbrev.length > 2 ? abbrev.substring(0, 2).toUpperCase() : abbrev.toUpperCase();
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark.withAlpha(26),
        borderRadius: BorderRadius.circular(_DS.radiusSm),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w800, color: UpriseColors.primaryDark)),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionIcon({required this.icon, required this.tooltip, this.onTap, this.color});

  @override
  Widget build(BuildContext context) => Tooltip(
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

// ─────────────────────────────────────────────────────────────────────────────
// OrgModel with logo
// ─────────────────────────────────────────────────────────────────────────────
class OrgModel {
  final String id, name, abbrev, tag, logoUrl;
  const OrgModel({
    required this.id, 
    required this.name, 
    required this.abbrev, 
    required this.tag,
    required this.logoUrl,
  });
  
  factory OrgModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrgModel(
      id: doc.id,
      name: d['name'] ?? d['orgName'] ?? d['organizationName'] ?? '',
      abbrev: d['shortName'] ?? d['abbrev'] ?? d['abbreviation'] ?? d['acronym'] ?? '',
      tag: d['tag'] ?? d['department'] ?? d['type'] ?? '',
      logoUrl: d['logoUrl'] ?? '',
    );
  }
}

// Officer info for view dialog
class OfficerInfo {
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  
  const OfficerInfo({
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
  });
  
  factory OfficerInfo.fromMap(Map<String, dynamic> map) {
    return OfficerInfo(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class AdviserRoles extends StatefulWidget {
  const AdviserRoles({super.key});
  @override
  State<AdviserRoles> createState() => _AdviserRolesState();
}

class _AdviserRolesState extends State<AdviserRoles> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter    = 'All';
  String _filterOrgId     = 'All';
  String _filterAdviserName = 'All';
  int    _currentPage     = 1;
  static const int _pageSize = 10;

  List<OrgModel> _orgs          = [];
  List<String>   _adviserNames  = [];
  bool           _loadingMeta   = true;
  int            _totalAdvisers = 0;
  int            _totalOfficers = 0;
  late StreamSubscription _metaListener;
  late StreamSubscription _officersListener;

  // Cache for officer data by orgId
  Map<String, Map<String, OfficerInfo>> _officersCache = {};

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _setupMetaListener();
    _setupOfficersListener();
  }

  @override
  void dispose() {
    _metaListener.cancel();
    _officersListener.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupMetaListener() {
    _metaListener = FirebaseFirestore.instance
        .collection('adviser_roles')
        .snapshots()
        .listen((_) => _loadMeta());
  }

  void _setupOfficersListener() {
    _officersListener = FirebaseFirestore.instance
        .collectionGroup('officers')
        .snapshots()
        .listen((snapshot) {
          _loadOfficersForAllOrgs();
        });
  }

  Future<void> _loadOfficersForAllOrgs() async {
    for (final org in _orgs) {
      await _loadOfficersForOrg(org.id);
    }
    setState(() {});
  }

  Future<void> _loadOfficersForOrg(String orgId) async {
    try {
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      
      final orgData = orgDoc.data();
      final adviserPhotoUrl = orgData?['adviserPhotoUrl'] ?? '';
      
      final roleSnap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('orgId', isEqualTo: orgId)
          .where('archived', isEqualTo: false)
          .get();
      
      for (final doc in roleSnap.docs) {
        if (adviserPhotoUrl.isNotEmpty) {
          await doc.reference.update({'adviserPhotoUrl': adviserPhotoUrl});
        }
      }
      
      final officerSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('officers')
          .get();
      
      final officers = <String, OfficerInfo>{};
      for (final doc in officerSnap.docs) {
        final data = doc.data();
        final position = (data['position'] ?? '').toString().toLowerCase();
        final officer = OfficerInfo.fromMap(data);
        
        if (position == 'president') {
          officers['president'] = officer;
        } else if (position == 'vice president') {
          officers['vicePresident'] = officer;
        } else if (position == 'secretary') {
          officers['secretary'] = officer;
        }
      }
      
      _officersCache[orgId] = officers;
      await _syncAdviserRoleOfficers(orgId, officers);
      
    } catch (e) {
      debugPrint('Error loading officers for org $orgId: $e');
    }
  }

  Future<void> _syncAdviserRoleOfficers(String orgId, Map<String, OfficerInfo> officers) async {
    try {
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      
      final orgData = orgDoc.data();
      final adviserPhotoUrl = orgData?['adviserPhotoUrl'] ?? '';
      
      final roleSnap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('orgId', isEqualTo: orgId)
          .where('archived', isEqualTo: false)
          .get();
      
      for (final doc in roleSnap.docs) {
        final updates = <String, dynamic>{};
        
        if (adviserPhotoUrl.isNotEmpty) {
          updates['adviserPhotoUrl'] = adviserPhotoUrl;
        }
        
        if (officers.containsKey('president')) {
          updates['president'] = officers['president']!.name;
          updates['presidentEmail'] = officers['president']!.email;
          updates['presidentPhone'] = officers['president']!.phone;
          updates['presidentPhotoUrl'] = officers['president']!.photoUrl;
        }
        
        if (officers.containsKey('vicePresident')) {
          updates['vicePresident'] = officers['vicePresident']!.name;
          updates['vicePresidentEmail'] = officers['vicePresident']!.email;
          updates['vicePresidentPhone'] = officers['vicePresident']!.phone;
          updates['vicePresidentPhotoUrl'] = officers['vicePresident']!.photoUrl;
        }
        
        if (officers.containsKey('secretary')) {
          updates['secretary'] = officers['secretary']!.name;
          updates['secretaryEmail'] = officers['secretary']!.email;
          updates['secretaryPhone'] = officers['secretary']!.phone;
          updates['secretaryPhotoUrl'] = officers['secretary']!.photoUrl;
        }
        
        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
        }
      }
    } catch (e) {
      debugPrint('Error syncing adviser role officers for org $orgId: $e');
    }
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    try {
      final orgSnap = await FirebaseFirestore.instance.collection('organizations').get();
      final orgs    = orgSnap.docs.map(OrgModel.fromDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final rolesSnap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('archived', isEqualTo: false)
          .get();

      final validRoles = rolesSnap.docs.where((doc) {
        final d = doc.data();
        final orgId = (d['orgId'] ?? '').toString().trim();
        final orgName = (d['orgName'] ?? '').toString().trim();
        return orgId.isNotEmpty && orgName.isNotEmpty;
      }).toList();

      int officers = 0;
      final namesSet = <String>{};
      for (final doc in validRoles) {
        final d = doc.data();
        if ((d['president'] ?? '').toString().trim().isNotEmpty) officers++;
        if ((d['vicePresident'] ?? '').toString().trim().isNotEmpty) officers++;
        if ((d['secretary'] ?? '').toString().trim().isNotEmpty) officers++;
        final n = d['adviserName']?.toString().trim();
        if (n != null && n.isNotEmpty) namesSet.add(n);
      }

      setState(() {
        _orgs          = orgs;
        _adviserNames  = namesSet.toList()..sort();
        _totalAdvisers = validRoles.length;
        _totalOfficers = officers;
        _loadingMeta   = false;
      });
      
      for (final org in orgs) {
        await _loadOfficersForOrg(org.id);
      }
      
    } catch (e) {
      setState(() => _loadingMeta = false);
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
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Row(children: [
        _StatCard(label: 'Total Advisers',   value: '$_totalAdvisers', icon: Icons.supervisor_account_rounded, color: UpriseColors.primaryDark),
        const SizedBox(width: 14),
        _StatCard(label: 'Total Officers',   value: '$_totalOfficers', icon: Icons.groups_rounded,             color: const Color(0xFF059669)),
        const SizedBox(width: 14),
        _StatCard(label: 'Organizations',    value: '${_orgs.length}', icon: Icons.business_rounded,           color: const Color(0xFF2563EB)),
        const SizedBox(width: 14),
        _StatCard(label: 'Archived Records', value: '—',              icon: Icons.archive_rounded,            color: const Color(0xFF64748B),
            stream: FirebaseFirestore.instance
                .collection('adviser_roles')
                .where('archived', isEqualTo: true)
                .snapshots()),
      ]),
    );
  }

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
                hintText: 'Search by org, adviser, or officer…',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
              ),
              onChanged: (_) => setState(() => _currentPage = 1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _TabToggle(
          options: const ['All', 'Archived'],
          selected: _statusFilter,
          onChanged: (v) => setState(() { _statusFilter = v; _currentPage = 1; }),
        ),
        const SizedBox(width: 10),
        _FilterDropdown(
          value: _filterOrgId,
          hint: 'All Orgs',
          icon: Icons.business_outlined,
          items: [
            const DropdownMenuItem(value: 'All', child: Text('All Orgs')),
            ..._orgs.map((o) => DropdownMenuItem(
                  value: o.id,
                  child: Text(o.abbrev.isNotEmpty ? o.abbrev : o.name),
                )),
          ],
          onChanged: (v) => setState(() { _filterOrgId = v ?? 'All'; _currentPage = 1; }),
        ),
        const SizedBox(width: 10),
        _FilterDropdown(
          value: _filterAdviserName,
          hint: 'All Advisers',
          icon: Icons.person_outline_rounded,
          items: [
            const DropdownMenuItem(value: 'All', child: Text('All Advisers')),
            ..._adviserNames.map((n) => DropdownMenuItem(value: n, child: Text(n))),
          ],
          onChanged: (v) => setState(() { _filterAdviserName = v ?? 'All'; _currentPage = 1; }),
        ),
        const SizedBox(width: 10),
        AdminExportButton(onSelected: (choice) {
          if (choice == 'csv') {
            _exportCSV();
          } else if (choice == 'pdf') {
            _exportPDF();
          }
        }),
      ]),
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('archived', isEqualTo: _statusFilter == 'Archived')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        var docs = snap.data?.docs ?? [];

        docs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final orgId = (data['orgId'] ?? '').toString().trim();
          final orgName = (data['orgName'] ?? '').toString().trim();
          return orgId.isNotEmpty && orgName.isNotEmpty;
        }).toList();

        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['orgName']     ?? '').toString().toLowerCase().contains(term) ||
                   (data['orgAbbrev']   ?? '').toString().toLowerCase().contains(term) ||
                   (data['adviserName'] ?? '').toString().toLowerCase().contains(term) ||
                   (data['president']   ?? '').toString().toLowerCase().contains(term) ||
                   (data['vicePresident'] ?? '').toString().toLowerCase().contains(term) ||
                   (data['secretary']   ?? '').toString().toLowerCase().contains(term);
          }).toList();
        }
        if (_filterOrgId != 'All') {
          docs = docs.where((d) => (d.data() as Map)['orgId'] == _filterOrgId).toList();
        }
        if (_filterAdviserName != 'All') {
          docs = docs.where((d) => (d.data() as Map)['adviserName'] == _filterAdviserName).toList();
        }

        final totalPages = docs.isEmpty ? 1 : (docs.length / _pageSize).ceil();
        final safePage   = _currentPage.clamp(1, totalPages);
        final start      = (safePage - 1) * _pageSize;
        final end        = (start + _pageSize).clamp(0, docs.length);
        final pageDocs   = docs.isEmpty ? <QueryDocumentSnapshot>[] : docs.sublist(start, end);

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
                        final data = pageDocs[i].data() as Map<String, dynamic>;
                        return _buildRow(docId: pageDocs[i].id, data: data, isLast: i == pageDocs.length - 1);
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
    ),
    child: Row(children: [
      Expanded(flex: 2, child: _headerCell('ORGANIZATION')),
      Expanded(flex: 2, child: _headerCell('ADVISER NAME')),
      Expanded(flex: 2, child: _headerCell('EMAIL')),
      Expanded(flex: 1, child: _headerCell('PHONE')),
      Expanded(flex: 1, child: _headerCell('POSITION')),
      Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: _headerCell('ACTIONS'))),
    ]),
  );
}

  Widget _headerCell(String text) => Text(text,
      style: GoogleFonts.beVietnamPro(
          fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.7));

  Widget _buildRow({required String docId, required Map<String, dynamic> data, required bool isLast}) {
  final position = data['adviserPosition'] ?? data['adviserRank'] ?? 'Faculty';
  final archived = data['archived'] == true;
  final orgId = data['orgId'] ?? '';
  
  final org = _orgs.firstWhere((o) => o.id == orgId, orElse: () => const OrgModel(id: '', name: '', abbrev: '', tag: '', logoUrl: ''));
  final orgLogoUrl = org.logoUrl;
  
  final adviserName = data['adviserName'] ?? '—';
  final adviserEmail = data['adviserEmail'] ?? '—';
  final adviserPhone = data['adviserPhone'] ?? '—';

  return InkWell(
    hoverColor: const Color(0xFFF8F9FB),
    onTap: () => _showViewDialog(data, docId),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(children: [
        // ORGANIZATION column
        Expanded(
          flex: 2,
          child: Row(children: [
            _OrgAvatar(data['orgAbbrev'] ?? '??', logoUrl: orgLogoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['orgName'] ?? '—',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C)),
                    overflow: TextOverflow.ellipsis),
                if ((data['orgTag'] ?? '').toString().isNotEmpty)
                  Text(data['orgTag'] ?? '',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
        
        // ADVISER NAME column
        Expanded(
          flex: 2,
          child: Text(adviserName,
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
              overflow: TextOverflow.ellipsis),
        ),
        
        // EMAIL column
        Expanded(
          flex: 2,
          child: Text(adviserEmail,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis),
        ),
        
        // PHONE column
        Expanded(
          flex: 1,
          child: Text(adviserPhone,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis),
        ),
        
        // POSITION column
        // POSITION column
Expanded(
  flex: 1,
  child: Text(position,
      style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
      overflow: TextOverflow.ellipsis),
),
        
        // ACTIONS column
        Expanded(
          flex: 1,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionIcon(
              icon: Icons.visibility_outlined,
              tooltip: 'View Details',
              onTap: () => _showViewDialog(data, docId),
            ),
            const SizedBox(width: 2),
            _ActionIcon(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              color: UpriseColors.primaryDark,
              onTap: () => _showEditDialog(data, docId),
            ),
            const SizedBox(width: 2),
            _ActionIcon(
              icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              tooltip: archived ? 'Restore' : 'Archive',
              color: const Color(0xFF64748B),
              onTap: archived
                  ? () => _restoreRecord(docId, data['orgName'] ?? '')
                  : () => _confirmArchive(docId, data['orgName'] ?? ''),
            ),
            const SizedBox(width: 2),
            _ActionIcon(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete',
              color: UpriseColors.error,
              onTap: () => _confirmDelete(docId, data['orgName'] ?? ''),
            ),
          ]),
        ),
      ]),
    ),
  );
}

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.supervisor_account_rounded, size: 36, color: Color(0xFF9AA5B4)),
        ),
        const SizedBox(height: 16),
        Text(
          _statusFilter == 'Archived' ? 'No archived records' : 'No adviser roles assigned yet',
          style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
        ),
        const SizedBox(height: 6),
        Text(
          _statusFilter == 'Archived'
              ? 'Archived roles will appear here.'
              : 'Tap "Assign Role" to get started.',
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          'Showing ${total == 0 ? 0 : start + 1}–$end of $total records',
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        Row(children: [
          _PageButton(icon: Icons.chevron_left_rounded,  enabled: _currentPage > 1,          onTap: () => setState(() => _currentPage--)),
          const SizedBox(width: 4),
          ...pages.map((p) => _PageNumButton(
                page: p, isActive: p == _currentPage,
                onTap: () => setState(() => _currentPage = p),
              )),
          if (lastPage < totalPages) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12)),
            ),
            _PageNumButton(
              page: totalPages, isActive: _currentPage == totalPages,
              onTap: () => setState(() => _currentPage = totalPages),
            ),
          ],
          const SizedBox(width: 4),
          _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
        ]),
      ]),
    );
  }

  // ── View dialog with photos ────────────────────────────────────────────────
  void _showViewDialog(Map<String, dynamic> data, String docId) {
    final rank = data['adviserRank'] ?? 'Instructor';
    final archived = data['archived'] == true;
    
    final presidentPhoto = data['presidentPhotoUrl'] ?? '';
    final vicePresidentPhoto = data['vicePresidentPhotoUrl'] ?? '';
    final secretaryPhoto = data['secretaryPhotoUrl'] ?? '';

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                _OrgAvatar(data['orgAbbrev'] ?? '??'),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['orgName'] ?? '—',
                        style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    if ((data['orgTag'] ?? '').toString().isNotEmpty)
                      Text(data['orgTag'] ?? '',
                          style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white.withAlpha(179))),
                  ]),
                ),
                if (archived)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('ARCHIVED',
                        style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                _viewCard('Adviser', [
                  _buildAdviserRow('Name', data['adviserName'] ?? '—', Icons.badge_outlined, data['adviserPhotoUrl'] ?? ''),
                  _buildInfoRow('Email', data['adviserEmail'] ?? '—', Icons.email_outlined),
                  _buildInfoRow('Phone', data['adviserPhone'] ?? '—', Icons.phone_outlined),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
  Row(children: [
    const Icon(Icons.work_outline, size: 13, color: Color(0xFF9AA5B4)),
    const SizedBox(width: 6),
    Text('Position', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
  ]),
  _PositionBadge(rank),
]),
                ]),
                const SizedBox(height: 12),
                _viewCard('Officers', [
                  _buildOfficerRow('President', data['president'] ?? '—', Icons.star_outline_rounded, presidentPhoto),
                  _buildOfficerRow('Vice President', data['vicePresident'] ?? '—', Icons.person_outline_rounded, vicePresidentPhoto),
                  _buildOfficerRow('Secretary', data['secretary'] ?? '—', Icons.person_outline_rounded, secretaryPhoto),
                ]),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(children: [
                if (!archived)
                  OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _confirmArchive(docId, data['orgName'] ?? ''); },
                    icon: const Icon(Icons.archive_outlined, size: 15),
                    label: Text('Archive', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                  ),
                if (archived)
                  OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _restoreRecord(docId, data['orgName'] ?? ''); },
                    icon: const Icon(Icons.unarchive_outlined, size: 15, color: Color(0xFF059669)),
                    label: Text('Restore', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF059669))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6EE7B7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showEditDialog(data, docId); },
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text('Edit', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _viewCard(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: UpriseColors.primaryDark, letterSpacing: 0.5)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFE2E6EA), thickness: 1)),
        ]),
        const SizedBox(height: 8),
        ...rows,
      ]),
    );
  }

  Widget _buildAdviserRow(String label, String value, IconData icon, String photoUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        if (photoUrl.isNotEmpty) ...[
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: _buildImageWidget(photoUrl, fit: BoxFit.cover, width: 32, height: 32),
          ),
          const SizedBox(width: 10),
        ],
        if (photoUrl.isEmpty) ...[
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: UpriseColors.primaryDark),
          ),
          const SizedBox(width: 10),
        ],
        SizedBox(
          width: 100,
          child: Text(label,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: UpriseColors.primaryDark.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: UpriseColors.primaryDark),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildOfficerRow(String label, String value, IconData icon, String photoUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        if (photoUrl.isNotEmpty) ...[
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: _buildImageWidget(photoUrl, fit: BoxFit.cover, width: 28, height: 28),
          ),
          const SizedBox(width: 8),
        ],
        if (photoUrl.isEmpty) ...[
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: UpriseColors.primaryDark),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 100,
          child: Text(label,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ── Form dialog (Edit) ──────────────────────────────────────
  void _showEditDialog(Map<String, dynamic> data, String docId) =>
      _showFormDialog(isEdit: true, docId: docId, existing: data);

  void _showFormDialog({
    required bool isEdit,
    required String? docId,
    required Map<String, dynamic>? existing,
  }) {
    OrgModel? selectedOrg = isEdit
        ? _orgs.cast<OrgModel?>().firstWhere((o) => o?.id == existing?['orgId'], orElse: () => null)
        : null;

    final advNameCtrl  = TextEditingController(text: existing?['adviserName']  ?? '');
    final advEmailCtrl = TextEditingController(text: existing?['adviserEmail'] ?? '');
    final advPhoneCtrl = TextEditingController(text: existing?['adviserPhone'] ?? '');
    final advRankCtrl  = TextEditingController(text: existing?['adviserRank']  ?? 'Instructor');
    final presCtrl     = TextEditingController(text: existing?['president']    ?? '');
    final vpCtrl       = TextEditingController(text: existing?['vicePresident'] ?? '');
    final secCtrl      = TextEditingController(text: existing?['secretary']    ?? '');
    final formKey      = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          bool    isSaving = false;
          String? errorMsg;

          Future<void> onOrgChanged(OrgModel? org) async {
            if (org == null || isEdit) return;
            final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(org.id).get();
            if (orgDoc.exists) {
              final d = orgDoc.data()!;
              setDlg(() {
                advNameCtrl.text  = d['adviserName']  ?? '';
                advEmailCtrl.text = d['adviserEmail'] ?? '';
                advPhoneCtrl.text = d['adviserPhone'] ?? '';
                advRankCtrl.text  = d['adviserTitle'] ?? 'Instructor';
              });
            }
          }

          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            if (selectedOrg == null) {
              setDlg(() => errorMsg = 'Please select an organization.');
              return;
            }
            setDlg(() { isSaving = true; errorMsg = null; });
            try {
              final payload = <String, dynamic>{
                'orgId':        selectedOrg!.id,
                'orgName':      selectedOrg!.name,
                'orgAbbrev':    selectedOrg!.abbrev,
                'orgTag':       selectedOrg!.tag,
                'adviserName':  advNameCtrl.text.trim(),
                'adviserEmail': advEmailCtrl.text.trim(),
                'adviserPhone': advPhoneCtrl.text.trim(),
                'adviserRank':  advRankCtrl.text.trim(),
                'president':    presCtrl.text.trim(),
                'vicePresident': vpCtrl.text.trim(),
                'secretary':    secCtrl.text.trim(),
                'archived':     false,
              };
              if (isEdit && docId != null) {
                await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).update(payload);
                await activity_log.ActivityLogger.log(
                  action: 'Updated adviser role for ${selectedOrg!.name}',
                  module: 'Adviser Roles', severity: 'info',
                  details: {'orgId': selectedOrg!.id, 'adviser': advNameCtrl.text.trim()},
                );
              } else {
                final dup = await FirebaseFirestore.instance
                    .collection('adviser_roles')
                    .where('orgId', isEqualTo: selectedOrg!.id)
                    .where('archived', isEqualTo: false)
                    .get();
                if (dup.docs.isNotEmpty) {
                  setDlg(() { isSaving = false; errorMsg = '${selectedOrg!.name} already has an active adviser role.'; });
                  return;
                }
                payload['createdAt'] = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance.collection('adviser_roles').add(payload);
                await activity_log.ActivityLogger.log(
                  action: 'Assigned new adviser role for ${selectedOrg!.name}',
                  module: 'Adviser Roles', severity: 'info',
                  details: {'orgId': selectedOrg!.id, 'adviser': advNameCtrl.text.trim()},
                );
              }
              _loadMeta();
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEdit ? 'Adviser role updated.' : 'Adviser role assigned.'),
                  backgroundColor: const Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ));
            } catch (e) {
              setDlg(() { isSaving = false; errorMsg = e.toString(); });
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Container(
              width: 540,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                          isEdit ? Icons.edit_outlined : Icons.person_add_alt_1_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Adviser Role' : 'Assign Adviser Role',
                        style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _sectionDivider('Organization', icon: Icons.business_outlined),
                        DropdownButtonFormField<OrgModel>(
                          initialValue: selectedOrg,
                          isExpanded: true,
                          decoration: _DS.inputDecoration('Select Organization', icon: Icons.business_outlined),
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                          items: _orgs.map((o) => DropdownMenuItem(
                            value: o,
                            child: Row(children: [
                              _OrgAvatar(o.abbrev.isNotEmpty ? o.abbrev : o.name.substring(0, o.name.length.clamp(0, 2)), logoUrl: o.logoUrl),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(o.name, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (o.tag.isNotEmpty)
                                    Text(o.tag, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                                ],
                              )),
                            ]),
                          )).toList(),
                          onChanged: (v) { setDlg(() => selectedOrg = v); onOrgChanged(v); },
                          validator: (_) => selectedOrg == null ? 'Select an organization' : null,
                        ),
                        const SizedBox(height: 20),
                        _sectionDivider('Adviser Information', icon: Icons.person_outline_rounded),
                        TextFormField(
                          controller: advNameCtrl,
                          decoration: _DS.inputDecoration('Full Name', hint: 'e.g., Dr. Juan dela Cruz', icon: Icons.badge_outlined),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: advEmailCtrl,
                              decoration: _DS.inputDecoration('Email', icon: Icons.email_outlined),
                              style: GoogleFonts.beVietnamPro(fontSize: 13),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: advPhoneCtrl,
                              decoration: _DS.inputDecoration('Phone', icon: Icons.phone_outlined),
                              style: GoogleFonts.beVietnamPro(fontSize: 13),
                              keyboardType: TextInputType.phone,
                              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
  initialValue: ['Dean', 'Program Chair', 'Department Head', 'Coordinator', 'Faculty'].contains(advRankCtrl.text)
      ? advRankCtrl.text
      : 'Faculty',
  decoration: _DS.inputDecoration('Position'),
  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
  items: ['Dean', 'Program Chair', 'Department Head', 'Coordinator', 'Faculty']
      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
      .toList(),
  onChanged: (v) { if (v != null) advRankCtrl.text = v; },
  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
),                     const SizedBox(height: 20),
                        _sectionDivider('Officers', icon: Icons.groups_outlined),
                        TextFormField(
                          controller: presCtrl,
                          decoration: _DS.inputDecoration('President', icon: Icons.star_outline_rounded),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: vpCtrl,
                          decoration: _DS.inputDecoration('Vice President', icon: Icons.person_outline_rounded),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: secCtrl,
                          decoration: _DS.inputDecoration('Secretary', icon: Icons.person_outline_rounded),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        if (errorMsg != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(errorMsg!,
                                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF991B1B)))),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                    color: Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E6EA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: isSaving ? null : save,
                      icon: isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 16),
                      label: Text(isEdit ? 'Save Changes' : 'Assign Role',
                          style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
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
        },
      ),
    );
  }

  // ── Confirm dialogs ───────────────────────────────────────────────
  void _confirmArchive(String docId, String orgName) {
    _confirmAction(
      title: 'Archive Record',
      message: 'Archive "$orgName"? It will be moved to the Archived tab and can be restored later.',
      confirmLabel: 'Archive',
      confirmColor: const Color(0xFF64748B),
      icon: Icons.archive_outlined,
      iconBg: const Color(0xFFF1F5F9),
      onConfirm: () async {
        await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).update({'archived': true});
        await activity_log.ActivityLogger.log(
            action: 'Archived adviser role for $orgName', module: 'Adviser Roles', severity: 'info');
        _loadMeta();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Record archived.'),
            backgroundColor: const Color(0xFF64748B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
      },
    );
  }

  Future<void> _restoreRecord(String docId, String orgName) async {
    await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).update({'archived': false});
    await activity_log.ActivityLogger.log(
        action: 'Restored adviser role for $orgName', module: 'Adviser Roles', severity: 'info');
    _loadMeta();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Record restored.'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  void _confirmDelete(String docId, String orgName) {
    _confirmAction(
      title: 'Delete Record',
      message: 'Permanently delete "$orgName"? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: UpriseColors.error,
      icon: Icons.delete_outline_rounded,
      iconBg: const Color(0xFFFEF2F2),
      onConfirm: () async {
        await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).delete();
        await activity_log.ActivityLogger.log(
            action: 'Deleted adviser role for $orgName', module: 'Adviser Roles', severity: 'warning');
        _loadMeta();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Record deleted.'),
            backgroundColor: UpriseColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
      },
    );
  }

  void _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
    required Color iconBg,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: confirmColor, size: 20),
              ),
              const SizedBox(width: 14),
              Text(title,
                  style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
            ]),
            const SizedBox(height: 14),
            Text(message,
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E6EA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () { Navigator.pop(ctx); onConfirm(); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: Text(confirmLabel, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Export ────────────────────────────────────────────────────────
  Future<void> _exportCSV() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('archived', isEqualTo: _statusFilter == 'Archived')
          .get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('No data to export.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
        return;
      }
      String esc(String s) => '"${s.replaceAll('"', '""')}"';
      final buf = StringBuffer();
      buf.writeln('Organization,Abbreviation,Tag,Adviser,Email,Phone,Rank,President,President Photo,Vice President,Vice President Photo,Secretary,Secretary Photo,Status');
      for (final doc in snap.docs) {
        final d = doc.data();
        buf.writeln([
          esc(d['orgName'] ?? ''), esc(d['orgAbbrev'] ?? ''), esc(d['orgTag'] ?? ''),
          esc(d['adviserName'] ?? ''), esc(d['adviserEmail'] ?? ''), esc(d['adviserPhone'] ?? ''),
          esc(d['adviserRank'] ?? ''), esc(d['president'] ?? ''), esc(d['presidentPhotoUrl'] ?? ''),
          esc(d['vicePresident'] ?? ''), esc(d['vicePresidentPhotoUrl'] ?? ''),
          esc(d['secretary'] ?? ''), esc(d['secretaryPhotoUrl'] ?? ''),
          esc((d['archived'] ?? false) ? 'Archived' : 'Active'),
        ].join(','));
      }
      final now  = DateTime.now().toString().substring(0, 10);
      final name = 'adviser_roles_$now.csv';
      await AdminExportUtil.saveText(
        buf.toString(),
        name,
        mimeType: 'text/csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
  }

  Future<void> _exportPDF() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('archived', isEqualTo: _statusFilter == 'Archived')
          .get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('No data to export.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
        return;
      }

      final rows = snap.docs.map((doc) {
        final d = doc.data();
        return [
          d['orgName'] ?? '',
          d['orgAbbrev'] ?? '',
          d['orgTag'] ?? '',
          d['adviserName'] ?? '',
          d['adviserEmail'] ?? '',
          d['adviserPhone'] ?? '',
          d['adviserRank'] ?? '',
          d['president'] ?? '',
          d['vicePresident'] ?? '',
          d['secretary'] ?? '',
          ((d['archived'] ?? false) ? 'Archived' : 'Active'),
        ].map((value) => value.toString()).toList();
      }).toList();

      final pdfBytes = await AdminExportPdf.generateTablePdf(
        title: 'Adviser Roles Report',
        headers: const ['Organization', 'Abbreviation', 'Tag', 'Adviser', 'Email', 'Phone', 'Rank', 'President', 'Vice President', 'Secretary', 'Status'],
        rows: rows,
      );
      final now = DateTime.now().toString().substring(0, 10);
      await AdminExportUtil.saveBytes(
        pdfBytes,
        'adviser_roles_$now.pdf',
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot>? stream;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.stream,
  });

  @override
  Widget build(BuildContext context) {
    Widget countWidget;
    if (stream != null) {
      countWidget = StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color));
          }
          final count = snap.hasData ? snap.data!.docs.length : 0;
          return Text('$count',
              style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1A202C)));
        },
      );
    } else {
      countWidget = Text(value,
          style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1A202C)));
    }

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
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              countWidget,
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _TabToggle({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Row(
        children: options.map((opt) {
          final isActive = opt == selected;
          return GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? UpriseColors.primaryDark : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(opt,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF64748B))),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _FilterDropdown({
    required this.value, required this.hint, required this.icon,
    required this.items, required this.onChanged,
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
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
          items: items,
          onChanged: onChanged,
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
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 20, color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
        ),
      );
}

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumButton({required this.page, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 28, height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? UpriseColors.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$page',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? Colors.white : const Color(0xFF374151))),
        ),
      );
}

class OrgColors {
  static const Color lightGray = Color(0xFFF5F5F5);
}