import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ---------- Data Models ----------
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

class Organization {
  final String id;
  final String name;
  final String shortName;
  final String type;
  final String description;
  final String adviserName;
  final String adviserTitle;
  final String adviserEmail;
  final String adviserPhone;
  final String logoUrl;
  final String status;
  final DateTime? createdAt;
  final List<String> categories;
  final List<Officer> officers;
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
    required this.logoUrl,
    required this.status,
    this.createdAt,
    required this.categories,
    required this.officers,
  });
}

// ---------- Main Widget ----------
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
      backgroundColor: UpriseColors.lightGray,
      body: _selectedOrganization != null
          ? OrganizationDetailPage(
              organization: _selectedOrganization!,
              onBack: () => setState(() => _selectedOrganization = null),
            )
          : _buildOrganizationList(),
    );
  }

  // ---------- MAIN LIST VIEW ----------
  Widget _buildOrganizationList() {
    return Column(
      children: [
        _buildHeader(),
        _buildStatsRow(),
        _buildToolbar(),
        const SizedBox(height: 16),
        Expanded(child: _buildTable()),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------- HEADER ----------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organization Management',
                    style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
                const SizedBox(height: 4),
                Text('Manage student organization status, advisers, and core details.',
                    style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showCreateOrganizationDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Organization'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UpriseColors.primaryDark,
              foregroundColor: UpriseColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- REAL‑TIME STATS ROW ----------
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
              case 'active': active++; break;
              case 'suspended': suspended++; break;
              case 'archived': archived++; break;
            }
          }
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            _statCard('TOTAL ORGANIZATIONS', '$total', UpriseColors.primaryDark),
            const SizedBox(width: 16),
            _statCard('ACTIVE', '$active', UpriseColors.success),
            const SizedBox(width: 16),
            _statCard('SUSPENDED', '$suspended', UpriseColors.warning),
            const SizedBox(width: 16),
            _statCard('ARCHIVED', '$archived', UpriseColors.darkGray),
          ]),
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ---------- TOOLBAR ----------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search organization, adviser...',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                  prefixIcon: const Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                  filled: true,
                  fillColor: UpriseColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: UpriseColors.mediumGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: UpriseColors.mediumGray),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (_) => setState(() => _currentPage = 1),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Status filter
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                items: ['All', 'Active', 'Suspended', 'Archived']
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Row(children: [
                            Icon(_statusIcon(status), size: 16, color: _statusColor(status)),
                            const SizedBox(width: 8),
                            Text(status, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                          ]),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _statusFilter = value!;
                  _currentPage = 1;
                }),
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
                icon: Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Type filter
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _typeFilter,
                items: _orgTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                )).toList(),
                onChanged: (value) => setState(() {
                  _typeFilter = value!;
                  _currentPage = 1;
                }),
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
                icon: Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Export button
          OutlinedButton.icon(
            onPressed: _exportOrganizations,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: UpriseColors.primaryDark,
              side: BorderSide(color: UpriseColors.mediumGray),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Active': return Icons.check_circle;
      case 'Suspended': return Icons.pause_circle;
      case 'Archived': return Icons.archive;
      default: return Icons.list;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active': return UpriseColors.success;
      case 'Suspended': return UpriseColors.warning;
      case 'Archived': return UpriseColors.darkGray;
      default: return UpriseColors.primaryDark;
    }
  }

  // ---------- TABLE ----------
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('organizations').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: UpriseColors.error)));
        }

        var docs = snapshot.data!.docs;
        if (_statusFilter != 'All') {
          docs = docs.where((doc) => (doc.data() as Map)['status'] == _statusFilter.toLowerCase()).toList();
        }
        if (_typeFilter != 'All Types') {
          docs = docs.where((doc) => (doc.data() as Map)['type'] == _typeFilter).toList();
        }
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final adviser = (data['adviserName'] ?? '').toString().toLowerCase();
            return name.contains(term) || adviser.contains(term);
          }).toList();
        }

        if (docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: UpriseColors.lightGray,
                    border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text('ORGANIZATION NAME', style: _headerStyle())),
                    Expanded(flex: 2, child: Text('ADVISER', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('DATE CREATED', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                  ]),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business, size: 64, color: UpriseColors.mediumGray),
                        const SizedBox(height: 16),
                        Text('No organizations found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final totalPages = (docs.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, docs.length);
        final pageDocs = docs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: UpriseColors.lightGray,
                  border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(children: [
                  Expanded(flex: 2, child: Text('ORGANIZATION NAME', style: _headerStyle())),
                  Expanded(flex: 2, child: Text('ADVISER', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('DATE CREATED', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: pageDocs.length,
                  itemBuilder: (_, i) {
                    final data = pageDocs[i].data() as Map<String, dynamic>;
                    final org = Organization(
                      id: pageDocs[i].id,
                      name: data['name'] ?? '',
                      shortName: data['shortName'] ?? '',
                      type: data['type'] ?? '',
                      description: data['description'] ?? '',
                      adviserName: data['adviserName'] ?? 'No Adviser',
                      adviserTitle: data['adviserTitle'] ?? '',
                      adviserEmail: data['adviserEmail'] ?? '',
                      adviserPhone: data['adviserPhone'] ?? '',
                      logoUrl: data['logoUrl'] ?? '',
                      status: data['status'] ?? 'active',
                      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                      categories: List<String>.from(data['categories'] ?? []),
                      officers: (data['officers'] as List?)?.map((e) => Officer.fromMap(e as Map<String, dynamic>)).toList() ?? [],
                    );
                    return _buildOrganizationRow(org);
                  },
                ),
              ),
              _buildFooter(docs.length, totalPages, start, end),
            ],
          ),
        );
      },
    );
  }

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
        color: UpriseColors.lightGray,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total organizations',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            color: _currentPage > 1 ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          ...pages.map((page) => GestureDetector(
                onTap: () => setState(() => _currentPage = page),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: page == _currentPage ? UpriseColors.primaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$page',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: page == _currentPage ? Colors.white : UpriseColors.charcoal,
                        fontWeight: page == _currentPage ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              )),
          if (lastPage < totalPages) ...[
            Text('...', style: TextStyle(color: UpriseColors.darkGray)),
            GestureDetector(
              onTap: () => setState(() => _currentPage = totalPages),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('$totalPages',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.charcoal)),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            color: _currentPage < totalPages ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ]),
      ]),
    );
  }

  Widget _buildOrganizationRow(Organization org) {
    final statusColor = org.status == 'active'
        ? UpriseColors.success
        : org.status == 'suspended'
            ? UpriseColors.warning
            : UpriseColors.darkGray;
    final statusLabel = org.status.toUpperCase();
    return GestureDetector(
      onTap: () => setState(() => _selectedOrganization = org),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(org.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 14, color: UpriseColors.charcoal)),
                  const SizedBox(height: 4),
                  Text(org.type, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(org.adviserName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: UpriseColors.charcoal)),
                  const SizedBox(height: 2),
                  Text(org.adviserTitle.isNotEmpty ? org.adviserTitle : 'Faculty Adviser',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(statusLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                org.createdAt != null ? _formatDate(org.createdAt!) : 'N/A',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: UpriseColors.darkGray),
                    onPressed: () => _showEditOrganizationDialog(org),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: Icon(org.status == 'archived' ? Icons.restore_outlined : Icons.archive_outlined, size: 18, color: UpriseColors.darkGray),
                    onPressed: () => _toggleArchiveOrganization(org),
                    tooltip: org.status == 'archived' ? 'Restore' : 'Archive',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOrganizationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateOrganizationDialog(onCreated: () => setState(() {})),
    );
  }

  void _showEditOrganizationDialog(Organization org) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditOrganizationDialog(organization: org, onUpdated: () => setState(() {})),
    );
  }

  Future<void> _toggleArchiveOrganization(Organization org) async {
    final isArchived = org.status == 'archived';
    final newStatus = isArchived ? 'active' : 'archived';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArchived ? 'Restore Organization' : 'Archive Organization'),
        content: Text('Are you sure you want to ${isArchived ? 'restore' : 'archive'} "${org.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('organizations').doc(org.id).update({'status': newStatus});
              await activity_log.ActivityLogger.log(
                action: isArchived ? 'Restored organization: ${org.name}' : 'Archived organization: ${org.name}',
                module: 'Organizations',
                severity: 'info',
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${org.name} has been ${isArchived ? 'restored' : 'archived'}')),
              );
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: isArchived ? UpriseColors.success : UpriseColors.primaryDark),
            child: Text(isArchived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
  }

  // ---------- EXPORT ----------
  Future<void> _exportOrganizations() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('organizations').get();
      final lines = <String>['Name,Short Name,Type,Description,Adviser Name,Adviser Title,Adviser Email,Adviser Phone,Status,Created At,Categories'];
      for (var doc in snap.docs) {
        final d = doc.data();
        lines.add([
          d['name'] ?? '',
          d['shortName'] ?? '',
          d['type'] ?? '',
          (d['description'] ?? '').replaceAll(',', ';'),
          d['adviserName'] ?? '',
          d['adviserTitle'] ?? '',
          d['adviserEmail'] ?? '',
          d['adviserPhone'] ?? '',
          d['status'] ?? '',
          (d['createdAt'] as Timestamp?)?.toDate().toString() ?? '',
          (d['categories'] as List?)?.join(';') ?? '',
        ].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/organizations.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'Organizations Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: UpriseColors.error),
      );
    }
  }

  String _formatDate(DateTime date) => '${_monthAbbr(date.month)} ${date.day}, ${date.year}';
  String _monthAbbr(int m) => ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][m-1];
}

// ---------- ENHANCED CREATE ORGANIZATION DIALOG (with multiple advisers) ----------
class CreateOrganizationDialog extends StatefulWidget {
  final VoidCallback onCreated;
  const CreateOrganizationDialog({super.key, required this.onCreated});
  @override
  _CreateOrganizationDialogState createState() => _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<CreateOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();
  String _type = 'Academic Organization';
  final _descCtrl = TextEditingController();
  final List<String> _categories = [];
  final _catCtrl = TextEditingController();
  File? _logoFile;
  bool _isLoading = false;

  // Primary adviser
  final _primaryNameCtrl = TextEditingController();
  final _primaryTitleCtrl = TextEditingController();
  final _primaryEmailCtrl = TextEditingController();
  final _primaryPhoneCtrl = TextEditingController();

  // Additional advisers
  final List<Map<String, TextEditingController>> _additionalAdvisers = [];

  @override
  void initState() {
    super.initState();
    // Start with one empty additional adviser
    _addAdviser();
  }

  void _addAdviser() {
    setState(() {
      _additionalAdvisers.add({
        'name': TextEditingController(),
        'title': TextEditingController(),
        'email': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeAdviser(int index) {
    setState(() {
      _additionalAdvisers[index].forEach((_, ctrl) => ctrl.dispose());
      _additionalAdvisers.removeAt(index);
    });
  }

  // Generate strong password
  String _generatePassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghjkmnpqrstuvwxyz';
    const digits = '23456789';
    const special = '@#\$!';
    final rand = Random.secure();
    final chars = [
      upper[rand.nextInt(upper.length)],
      upper[rand.nextInt(upper.length)],
      lower[rand.nextInt(lower.length)],
      lower[rand.nextInt(lower.length)],
      digits[rand.nextInt(digits.length)],
      digits[rand.nextInt(digits.length)],
      special[rand.nextInt(special.length)],
      ...List.generate(3, (_) {
        final all = upper + lower + digits + special;
        return all[rand.nextInt(all.length)];
      }),
    ]..shuffle(rand);
    return chars.join();
  }

  Future<void> _sendCredentialsEmail({
    required String toEmail,
    required String orgName,
    required String adviserName,
    required String password,
  }) async {
    await FirebaseFirestore.instance.collection('mail').add({
      'to': [toEmail],
      'message': {
        'subject': '🎓 UPRISE Portal — Your Organization Login Credentials',
        'html': '''
          <div style="font-family: sans-serif; max-width: 520px; margin: auto; border: 1px solid #FDE68A; border-radius: 12px; overflow: hidden;">
            <div style="background: linear-gradient(135deg, #D97706, #B45309); padding: 24px 32px;">
              <h1 style="color: white; margin: 0; font-size: 24px; letter-spacing: 2px;">UPRISE</h1>
              <p style="color: rgba(255,255,255,0.85); margin: 4px 0 0; font-size: 13px;">CICT Organization Management Portal</p>
            </div>
            <div style="padding: 32px;">
              <p style="font-size: 15px; color: #1E293B;">Hi <strong>$adviserName</strong>,</p>
              <p style="color: #475569; font-size: 14px; line-height: 1.6;">
                Your organization <strong>$orgName</strong> has been registered on the UPRISE Portal.
                Below are your login credentials. Please keep them secure and change your password after first login.
              </p>
              <div style="background: #FFF7ED; border: 1px solid #FDE68A; border-radius: 10px; padding: 20px 24px; margin: 24px 0;">
                <p style="margin: 0 0 10px; font-size: 13px; color: #92400E; font-weight: 600; letter-spacing: 1px;">YOUR LOGIN CREDENTIALS</p>
                <table style="width: 100%; font-size: 14px; color: #1E293B;">
                  <tr><td style="padding: 6px 0; color: #64748B; width: 120px;">Email</td><td style="font-weight: 600;">$toEmail</td></tr>
                  <tr><td style="padding: 6px 0; color: #64748B;">Password</td><td style="font-weight: 600; font-family: monospace; font-size: 16px; letter-spacing: 1px; color: #B45309;">$password</td></tr>
                  <tr><td style="padding: 6px 0; color: #64748B;">Portal</td><td><a href="https://your-uprise-url.web.app" style="color: #D97706;">Organization Portal →</a></td></tr>
                </table>
              </div>
              <p style="color: #94A3B8; font-size: 12px; margin-top: 24px;">If you did not expect this email, please contact your System Administrator immediately.</p>
            </div>
            <div style="background: #F8FAFC; padding: 16px 32px; border-top: 1px solid #E2E8F0;">
              <p style="color: #94A3B8; font-size: 11px; margin: 0;">© UPRISE — CICT Organization Management System</p>
            </div>
          </div>
        ''',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_business, color: UpriseColors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Create New Organization',
                        style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.white)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: UpriseColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Organization Logo
                      _sectionTitle('Organization Logo', Icons.image),
                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              color: UpriseColors.lightGray,
                              border: Border.all(color: UpriseColors.mediumGray, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _logoFile != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_logoFile!, fit: BoxFit.cover))
                                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Icons.cloud_upload, size: 32, color: UpriseColors.darkGray),
                                    const SizedBox(height: 8),
                                    Text('Click to upload', style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                                  ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Basic Information
                      _sectionTitle('Basic Information', Icons.info_outline),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Organization Name',
                          prefixIcon: Icon(Icons.business, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _shortNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Short Name (e.g., SWITS)',
                          prefixIcon: Icon(Icons.title, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: InputDecoration(
                          labelText: 'Organization Type',
                          prefixIcon: Icon(Icons.category, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          'Academic Organization',
                          'Student Government',
                          'Special Interest Group',
                          'Cultural Organization',
                          'Sports Organization'
                        ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Categories
                      _sectionTitle('Categories', Icons.label_outline),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._categories.map((c) => Chip(
                            label: Text(c, style: GoogleFonts.beVietnamPro(fontSize: 12)),
                            onDeleted: () => setState(() => _categories.remove(c)),
                            backgroundColor: UpriseColors.lightGray,
                          )),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _catCtrl,
                              decoration: InputDecoration(
                                hintText: 'Add',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onSubmitted: (v) {
                                if (v.isNotEmpty && !_categories.contains(v)) {
                                  setState(() => _categories.add(v));
                                  _catCtrl.clear();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Primary Adviser (will receive login credentials)
                      _sectionTitle('Primary Adviser (Login Account)', Icons.person),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _primaryNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _primaryTitleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Title / Position',
                          prefixIcon: Icon(Icons.work_outline, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _primaryEmailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _primaryPhoneCtrl,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone, color: UpriseColors.primaryDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      // Additional Advisers
                      _sectionTitle('Additional Advisers (Optional)', Icons.group_add),
                      const SizedBox(height: 8),
                      ..._additionalAdvisers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final controllers = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: UpriseColors.mediumGray)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('Additional Adviser ${idx + 1}', style: TextStyle(fontWeight: FontWeight.w600))),
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: UpriseColors.error),
                                      onPressed: () => _removeAdviser(idx),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: controllers['name']!,
                                  decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: controllers['title']!,
                                  decoration: InputDecoration(labelText: 'Title / Position', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: controllers['email']!,
                                  decoration: InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: controllers['phone']!,
                                  decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _addAdviser,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Another Adviser'),
                        style: TextButton.styleFrom(foregroundColor: UpriseColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: UpriseColors.darkGray)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: UpriseColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Organization'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final generatedPassword = _generatePassword();
    final primaryEmail = _primaryEmailCtrl.text.trim();

    try {
      // 1. Create Firebase Auth account for primary adviser
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: primaryEmail,
        password: generatedPassword,
      );
      final uid = userCredential.user!.uid;

      final batch = FirebaseFirestore.instance.batch();
      final orgRef = FirebaseFirestore.instance.collection('organizations').doc();

      // 2. Organization document
      batch.set(orgRef, {
        'name': _nameCtrl.text,
        'shortName': _shortNameCtrl.text,
        'type': _type,
        'description': _descCtrl.text,
        'adviserName': _primaryNameCtrl.text,
        'adviserTitle': _primaryTitleCtrl.text,
        'adviserEmail': primaryEmail,
        'adviserPhone': _primaryPhoneCtrl.text,
        'logoUrl': '',
        'status': 'active',
        'categories': _categories,
        'officers': [],
        'orgUserId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. User role document (for AuthWrapper)
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.set(userRef, {
        'role': 'org',
        'orgId': orgRef.id,
        'email': primaryEmail,
        'fullName': _primaryNameCtrl.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Primary adviser role
      final primaryRoleRef = FirebaseFirestore.instance.collection('adviser_roles').doc();
      batch.set(primaryRoleRef, {
        'orgId': orgRef.id,
        'orgName': _nameCtrl.text,
        'orgAbbrev': _shortNameCtrl.text,
        'orgTag': _type,
        'adviserId': uid,
        'adviserName': _primaryNameCtrl.text,
        'adviserEmail': primaryEmail,
        'adviserPhone': _primaryPhoneCtrl.text,
        'adviserRank': _primaryTitleCtrl.text,
        'president': '',
        'vicePresident': '',
        'secretary': '',
        'archived': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Additional advisers (no Auth accounts)
      for (var adviser in _additionalAdvisers) {
        final name = adviser['name']!.text.trim();
        final title = adviser['title']!.text.trim();
        final email = adviser['email']!.text.trim();
        final phone = adviser['phone']!.text.trim();
        if (name.isEmpty && email.isEmpty) continue; // skip empty
        final roleRef = FirebaseFirestore.instance.collection('adviser_roles').doc();
        batch.set(roleRef, {
          'orgId': orgRef.id,
          'orgName': _nameCtrl.text,
          'orgAbbrev': _shortNameCtrl.text,
          'orgTag': _type,
          'adviserId': '',  // no Auth account
          'adviserName': name,
          'adviserEmail': email,
          'adviserPhone': phone,
          'adviserRank': title,
          'president': '',
          'vicePresident': '',
          'secretary': '',
          'archived': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // 6. Send email to primary adviser
      await _sendCredentialsEmail(
        toEmail: primaryEmail,
        orgName: _nameCtrl.text,
        adviserName: _primaryNameCtrl.text,
        password: generatedPassword,
      );

      // 7. Activity log
      await activity_log.ActivityLogger.log(
        action: 'Created new organization: ${_nameCtrl.text}',
        module: 'Organizations',
        severity: 'info',
      );

      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization created & credentials sent to primary adviser email')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Account creation failed';
      if (e.code == 'email-already-in-use') {
        msg = 'This email already has an account. Please use a different email for primary adviser.';
      } else if (e.code == 'invalid-email') {
        msg = 'Invalid email address.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: UpriseColors.error),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: UpriseColors.primaryDark),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700, color: UpriseColors.charcoal)),
      ],
    );
  }
}

// ---------- EDIT ORGANIZATION DIALOG (unchanged, logging kept) ----------
class EditOrganizationDialog extends StatefulWidget {
  final Organization organization;
  final VoidCallback onUpdated;
  const EditOrganizationDialog({super.key, required this.organization, required this.onUpdated});
  @override
  _EditOrganizationDialogState createState() => _EditOrganizationDialogState();
}

class _EditOrganizationDialogState extends State<EditOrganizationDialog> {
  late TextEditingController _nameCtrl, _shortCtrl, _typeCtrl, _descCtrl, _advNameCtrl, _advTitleCtrl, _advEmailCtrl, _advPhoneCtrl;
  late String _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.organization.name);
    _shortCtrl = TextEditingController(text: widget.organization.shortName);
    _typeCtrl = TextEditingController(text: widget.organization.type);
    _descCtrl = TextEditingController(text: widget.organization.description);
    _advNameCtrl = TextEditingController(text: widget.organization.adviserName);
    _advTitleCtrl = TextEditingController(text: widget.organization.adviserTitle);
    _advEmailCtrl = TextEditingController(text: widget.organization.adviserEmail);
    _advPhoneCtrl = TextEditingController(text: widget.organization.adviserPhone);
    _status = widget.organization.status;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: UpriseColors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Edit Organization', style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: UpriseColors.white)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: UpriseColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _shortCtrl, decoration: const InputDecoration(labelText: 'Short Name', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _typeCtrl.text,
                    items: ['Academic Organization','Student Government','Special Interest Group','Cultural Organization','Sports Organization']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.beVietnamPro(fontSize: 13)))).toList(),
                    onChanged: (v) => _typeCtrl.text = v!,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    items: ['active','suspended','archived'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: GoogleFonts.beVietnamPro(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _advNameCtrl, decoration: const InputDecoration(labelText: 'Adviser Name', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _advTitleCtrl, decoration: const InputDecoration(labelText: 'Adviser Title', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _advEmailCtrl, decoration: const InputDecoration(labelText: 'Adviser Email', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _advPhoneCtrl, decoration: const InputDecoration(labelText: 'Adviser Phone', border: OutlineInputBorder())),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: UpriseColors.mediumGray))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: UpriseColors.darkGray))),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _update,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: UpriseColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: UpriseColors.white))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _update() async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      final orgRef = FirebaseFirestore.instance.collection('organizations').doc(widget.organization.id);
      batch.update(orgRef, {
        'name': _nameCtrl.text,
        'shortName': _shortCtrl.text,
        'type': _typeCtrl.text,
        'description': _descCtrl.text,
        'adviserName': _advNameCtrl.text,
        'adviserTitle': _advTitleCtrl.text,
        'adviserEmail': _advEmailCtrl.text,
        'adviserPhone': _advPhoneCtrl.text,
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final existingRoles = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('orgId', isEqualTo: widget.organization.id)
          .get();

      if (existingRoles.docs.isNotEmpty) {
        final roleRef = existingRoles.docs.first.reference;
        batch.update(roleRef, {
          'orgName': _nameCtrl.text,
          'orgAbbrev': _shortCtrl.text,
          'orgTag': _typeCtrl.text,
          'adviserName': _advNameCtrl.text,
          'adviserEmail': _advEmailCtrl.text,
          'adviserPhone': _advPhoneCtrl.text,
          'adviserRank': _advTitleCtrl.text,
        });
      } else {
        final newRoleRef = FirebaseFirestore.instance.collection('adviser_roles').doc();
        batch.set(newRoleRef, {
          'orgId': widget.organization.id,
          'orgName': _nameCtrl.text,
          'orgAbbrev': _shortCtrl.text,
          'orgTag': _typeCtrl.text,
          'adviserId': '',
          'adviserName': _advNameCtrl.text,
          'adviserEmail': _advEmailCtrl.text,
          'adviserPhone': _advPhoneCtrl.text,
          'adviserRank': _advTitleCtrl.text,
          'president': '',
          'vicePresident': '',
          'secretary': '',
          'archived': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await activity_log.ActivityLogger.log(
        action: 'Updated organization: ${widget.organization.name} → ${_nameCtrl.text}',
        module: 'Organizations',
        severity: 'info',
      );

      widget.onUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization updated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ---------- ORGANIZATION DETAIL PAGE (with fixed stats) ----------
class OrganizationDetailPage extends StatefulWidget {
  final Organization organization;
  final VoidCallback onBack;

  const OrganizationDetailPage({super.key, required this.organization, required this.onBack});

  @override
  _OrganizationDetailPageState createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage> {
  late ScrollController _scrollController;
  final GlobalKey _atGlanceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToAtGlance() {
    Scrollable.ensureVisible(
      _atGlanceKey.currentContext!,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _archiveOrganization() async {
    final isArchived = widget.organization.status == 'archived';
    final newStatus = isArchived ? 'active' : 'archived';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArchived ? 'Restore Organization' : 'Archive Organization'),
        content: Text('Are you sure you want to ${isArchived ? 'restore' : 'archive'} "${widget.organization.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isArchived ? UpriseColors.success : UpriseColors.primaryDark),
            child: Text(isArchived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('organizations').doc(widget.organization.id).update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.organization.name} has been ${isArchived ? 'restored' : 'archived'}')),
      );
      widget.onBack();
    }
  }

  void _manageOfficers() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manage Officers feature coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: UpriseColors.darkGray),
            onPressed: widget.onBack,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: UpriseColors.lightGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: widget.organization.logoUrl.isNotEmpty
                      ? Image.network(widget.organization.logoUrl, fit: BoxFit.cover)
                      : Icon(Icons.business, size: 50, color: UpriseColors.primaryDark),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.organization.name,
                        style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${widget.organization.type} • College of Information and Communications Technology',
                        style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.organization.status == 'active'
                              ? UpriseColors.success.withOpacity(0.1)
                              : UpriseColors.darkGray.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.organization.status.toUpperCase(),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.organization.status == 'active' ? UpriseColors.success : UpriseColors.darkGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _archiveOrganization,
                      icon: Icon(widget.organization.status == 'archived' ? Icons.restore_outlined : Icons.archive_outlined, size: 18),
                      label: Text(widget.organization.status == 'archived' ? 'Restore' : 'Archive'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.white,
                        foregroundColor: UpriseColors.darkGray,
                        side: BorderSide(color: UpriseColors.mediumGray),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _scrollToAtGlance,
                      icon: Icon(Icons.analytics_outlined, size: 18),
                      label: Text('At a Glance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.white,
                        foregroundColor: UpriseColors.darkGray,
                        side: BorderSide(color: UpriseColors.mediumGray),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _manageOfficers,
                      icon: Icon(Icons.people_outline, size: 18),
                      label: Text('Manage Officers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
                        foregroundColor: UpriseColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _infoCard(
                      'ABOUT THE ORGANIZATION',
                      Icons.info_outline,
                      Text(
                        widget.organization.description.isNotEmpty ? widget.organization.description : 'No description provided.',
                        style: GoogleFonts.beVietnamPro(fontSize: 14, height: 1.5, color: UpriseColors.darkGray),
                      ),
                    ),
                    SizedBox(height: 24),
                    _infoCard(
                      'FACULTY ADVISER',
                      Icons.school_outlined,
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: UpriseColors.lightGray,
                            radius: 32,
                            child: Text(
                              widget.organization.adviserName.isNotEmpty
                                  ? widget.organization.adviserName.split(' ').map((e) => e[0]).take(2).join()
                                  : 'NA',
                              style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.organization.adviserName.isNotEmpty ? widget.organization.adviserName : 'No Adviser Assigned',
                                  style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  widget.organization.adviserTitle.isNotEmpty ? widget.organization.adviserTitle : 'Department of Computer Science',
                                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                                ),
                                if (widget.organization.adviserEmail.isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    widget.organization.adviserEmail,
                                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.primaryDark),
                                  ),
                                ],
                                if (widget.organization.adviserPhone.isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    widget.organization.adviserPhone,
                                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      key: _atGlanceKey,
                      child: _buildAtGlanceStats(),
                    ),
                    SizedBox(height: 24),
                    _infoCard(
                      'CATEGORIES',
                      Icons.label_outline,
                      Wrap(
                        spacing: 8,
                        children: widget.organization.categories.isEmpty
                            ? [Text('No categories added', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray))]
                            : widget.organization.categories.map((cat) => Chip(
                                label: Text(cat, style: GoogleFonts.beVietnamPro(fontSize: 12)),
                                backgroundColor: UpriseColors.lightGray,
                              )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _infoCard(
                      'CURRENT OFFICERS (2025-2026)',
                      Icons.people_outline,
                      widget.organization.officers.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text('No officers assigned yet', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
                            )
                          : Column(
                              children: widget.organization.officers.map((o) => Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(o.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500, fontSize: 14)),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: UpriseColors.lightGray,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        o.position.toUpperCase(),
                                        style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                    ),
                    SizedBox(height: 24),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAtGlanceStats() {
    return Column(
      children: [
        _infoCard(
          'AT A GLANCE',
          Icons.timeline_outlined,
          StreamBuilder<Map<String, int>>(
            stream: _fetchOrganizationStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Error loading stats', style: GoogleFonts.beVietnamPro(color: UpriseColors.error)),
                );
              }
              final stats = snapshot.data ?? {'events': 0, 'pending': 0, 'achievements': 0};
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(Icons.event, 'Events Held', stats['events']!.toString()),
                  _statItem(Icons.pending_actions, 'Pending Req', stats['pending']!.toString()),
                  _statItem(Icons.emoji_events, 'Achievements', stats['achievements']!.toString()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<Map<String, int>> _fetchOrganizationStats() async* {
    final eventsQuery = await FirebaseFirestore.instance
        .collection('events')
        .where('organizationId', isEqualTo: widget.organization.id)
        .where('status', isEqualTo: 'completed')
        .count()
        .get();
    final eventsCount = eventsQuery.count;

    final proposalsQuery = await FirebaseFirestore.instance
        .collection('event_proposals')
        .where('organizationId', isEqualTo: widget.organization.id)
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    final pendingCount = proposalsQuery.count;

    final achievementsQuery = await FirebaseFirestore.instance
        .collection('achievements')
        .where('organizationId', isEqualTo: widget.organization.id)
        .count()
        .get();
    final achievementsCount = achievementsQuery.count;

    yield {
      'events': ?eventsCount,
      'pending': ?pendingCount,
      'achievements': ?achievementsCount,
    };
  }

  Widget _buildRecentActivity() {
    return _infoCard(
      'RECENT ACTIVITY',
      Icons.history,
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activity_logs')
            .where('organizationId', isEqualTo: widget.organization.id)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No recent activity', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray), textAlign: TextAlign.center),
            );
          }
          return Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _activityItem(
                data['title'] ?? 'Activity',
                data['description'] ?? '',
                data['createdAt'] as Timestamp?,
              );
            }).toList(),
          );
        },
      ),
      footer: TextButton(
        onPressed: () {},
        child: Text('View History', style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark)),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: UpriseColors.primaryDark, size: 28),
        SizedBox(height: 8),
        Text(value, style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
      ],
    );
  }

  Widget _infoCard(String title, IconData icon, Widget child, {Widget? footer}) {
    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: UpriseColors.primaryDark),
                SizedBox(width: 12),
                Text(title, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: UpriseColors.darkGray, letterSpacing: 0.5)),
              ],
            ),
          ),
          Divider(height: 0, color: UpriseColors.mediumGray),
          Padding(padding: EdgeInsets.all(16), child: child),
          if (footer != null) ...[
            Divider(height: 0, color: UpriseColors.mediumGray),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: footer),
          ],
        ],
      ),
    );
  }

  Widget _activityItem(String title, String subtitle, Timestamp? ts) {
    String time = _formatTimeAgo(ts);
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: UpriseColors.lightGray, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.event_available, color: UpriseColors.primaryDark, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500, fontSize: 13)),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
                SizedBox(height: 2),
                Text(time, style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(Timestamp? ts) {
    if (ts == null) return 'Just now';
    DateTime date = ts.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() == 1 ? '' : 's'} ago';
  }
}

